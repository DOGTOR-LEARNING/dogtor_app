import pandas as pd
import os
import vertexai
from vertexai.generative_models import GenerativeModel
import json
import time
from typing import Optional, List
import re

# 初始化 Vertex AI
vertexai.init(project="dogtor-454402", location="us-central1")

class QuestionKnowledgePointMatcher:
    def __init__(self):
        """初始化題目知識點匹配器"""
        self.model = GenerativeModel("gemini-2.0-flash")
        self.knowledge_points_df = None
        self.question_bank_df = None
        self.results = []
        self.output_path = "processing/question_knowledge_point_matching_results.csv"
        
    def load_data(self):
        """載入知識點和題庫資料，並檢查已處理的結果"""
        try:
            # 載入知識點資料
            self.knowledge_points_df = pd.read_csv("processing/jun_math_list.csv")
            print(f"載入知識點資料: {len(self.knowledge_points_df)} 筆記錄")
            
            # 載入題庫資料
            self.question_bank_df = pd.read_csv("processing/question_bank.csv")
            print(f"載入題庫資料: {len(self.question_bank_df)} 筆記錄")
            
            # 檢查是否有已處理的結果
            if os.path.exists(self.output_path):
                processed_df = pd.read_csv(self.output_path)
                processed_questions = set(processed_df['ques_no'].tolist())
                print(f"發現已處理的結果: {len(processed_questions)} 題")
                
                # 更新 results 列表
                self.results = processed_df.to_dict('records')
                
                # 過濾掉已處理的題目
                self.question_bank_df = self.question_bank_df[~self.question_bank_df['ques_no'].isin(processed_questions)]
                print(f"剩餘待處理題目: {len(self.question_bank_df)} 題")
            
            return True
        except Exception as e:
            print(f"載入資料失敗: {e}")
            return False
    
    def get_section_knowledge_points(self, chapter_name: str, section_name: str) -> List[str]:
        """根據章節和節次取得相關知識點"""
        try:
            # 只尋找完全匹配的節次
            filtered_df = self.knowledge_points_df[
                self.knowledge_points_df['section_name'] == section_name
            ]
            
            if filtered_df.empty:
                print(f"找不到完全匹配的節次: {section_name}")
                return []
            
            # 提取知識點
            knowledge_points = []
            for _, row in filtered_df.iterrows():
                if pd.notna(row['knowledge_points']):
                    points = str(row['knowledge_points']).split('、')
                    knowledge_points.extend([point.strip() for point in points if point.strip()])
            
            # 去重並排序
            return list(set(knowledge_points))
            
        except Exception as e:
            print(f"取得知識點失敗: {e}")
            return []
    
    def should_skip_question(self, question_text: str) -> tuple[bool, str]:
        """判斷是否應該跳過這道題目"""
        # 檢查是否提到圖片
        image_keywords = ['圖為', '圖片', '圖表', '下圖', '右圖', '左圖', '如圖', '圖中', '附圖']
        # image_keywords = []
        question_lower = question_text.lower()
        
        for keyword in image_keywords:
            if keyword in question_text:
                return True, f"題目提到圖片相關內容: {keyword}"
        
        # 檢查題目是否太短（可能不完整）
        if len(question_text.strip()) < 10:
            return True, "題目內容太短"
        
        return False, ""
    
    def call_gemini_api(self, question_text: str, knowledge_points: List[str], max_retries: int = 3) -> Optional[str]:
        """呼叫 Gemini API 進行知識點判斷"""
        if not knowledge_points:
            return None
        
        # 構建提示詞
        knowledge_points_str = "、".join(knowledge_points)
        prompt = f"""
請仔細分析以下題目，並從給定的知識點清單中選擇一個最相關的知識點。

題目內容：
{question_text}

可選的知識點清單：
{knowledge_points_str}

請注意以下要求：
1. 只能從上述知識點清單中選擇一個知識點
2. 選擇與題目內容最相關的知識點
3. 如果題目與任何知識點都不相關，請回覆「無匹配」
4. 請只回覆知識點名稱，不要有其他說明文字

回覆格式：知識點名稱
"""
        
        for attempt in range(max_retries):
            try:
                response = self.model.generate_content(prompt)
                result = response.text.strip()
                
                # 驗證回覆是否在知識點清單中
                if result in knowledge_points:
                    return result
                elif result == "無匹配":
                    return None
                else:
                    # 嘗試模糊匹配
                    for kp in knowledge_points:
                        if result in kp or kp in result:
                            return kp
                    
                    print(f"API 回覆不在知識點清單中: {result}")
                    if attempt < max_retries - 1:
                        time.sleep(1)
                        continue
                    return None
                    
            except Exception as e:
                print(f"API 呼叫失敗 (嘗試 {attempt + 1}/{max_retries}): {e}")
                if attempt < max_retries - 1:
                    time.sleep(2 ** attempt)  # 指數退避
                    continue
                return None
        
        return None
    
    def save_result(self, result: dict):
        """儲存單一題目的處理結果"""
        try:
            # 將結果加入列表
            self.results.append(result)
            
            # 轉換為 DataFrame
            results_df = pd.DataFrame([result])
            
            # 如果檔案不存在，創建新檔案
            if not os.path.exists(self.output_path):
                results_df.to_csv(self.output_path, index=False, encoding='utf-8-sig')
            else:
                # 追加到現有檔案
                results_df.to_csv(self.output_path, mode='a', header=False, index=False, encoding='utf-8-sig')
            
        except Exception as e:
            print(f"儲存結果失敗: {e}")
    
    def process_questions(self, batch_size: int = 10):
        """處理所有題目"""
        if self.question_bank_df is None or self.knowledge_points_df is None:
            print("請先載入資料")
            return
        
        total_questions = len(self.question_bank_df)
        processed = 0
        skipped = 0
        matched = 0
        
        print(f"開始處理 {total_questions} 道題目...")
        
        try:
            for idx, row in self.question_bank_df.iterrows():
                try:
                    question_text = str(row['ques_detl']) if pd.notna(row['ques_detl']) else ""
                    subject = str(row['subject']) if pd.notna(row['subject']) else ""
                    chapter_name = str(row['chapter name']) if pd.notna(row['chapter name']) else ""
                    section_name = str(row['section name']) if pd.notna(row['section name']) else ""
                    question_no = str(row['ques_no']) if pd.notna(row['ques_no']) else ""
                    
                    # 檢查是否需要跳過
                    should_skip, skip_reason = self.should_skip_question(question_text)
                    
                    result = {
                        'ques_no': question_no,
                        'subject': subject,
                        'chapter_name': chapter_name,
                        'section_name': section_name,
                        'question_text': question_text[:100] + "..." if len(question_text) > 100 else question_text,
                        'matched_knowledge_point': None,
                        'status': 'skipped' if should_skip else 'processed',
                        'reason': skip_reason if should_skip else ""
                    }
                    
                    if should_skip:
                        skipped += 1
                        print(f"[{processed + 1}/{total_questions}] 跳過題目 {question_no}: {skip_reason}")
                    else:
                        # 取得相關知識點
                        knowledge_points = self.get_section_knowledge_points(chapter_name, section_name)
                        
                        if not knowledge_points:
                            result['status'] = 'no_knowledge_points'
                            result['reason'] = "找不到相關知識點"
                            print(f"[{processed + 1}/{total_questions}] 題目 {question_no}: 找不到相關知識點")
                        else:
                            # 呼叫 Gemini API
                            matched_kp = self.call_gemini_api(question_text, knowledge_points)
                            
                            if matched_kp:
                                result['matched_knowledge_point'] = matched_kp
                                result['status'] = 'matched'
                                matched += 1
                                print(f"[{processed + 1}/{total_questions}] 題目 {question_no} 匹配到: {matched_kp}")
                            else:
                                result['status'] = 'no_match'
                                result['reason'] = "AI 判斷無匹配的知識點"
                                print(f"[{processed + 1}/{total_questions}] 題目 {question_no}: 無匹配的知識點")
                    
                    # 儲存這一題的結果
                    self.save_result(result)
                    processed += 1
                    
                    # 每處理一定數量的題目後暫停，避免 API 限制
                    if processed % batch_size == 0:
                        print(f"已處理 {processed} 道題目，暫停 1 秒...")
                        time.sleep(1)
                    
                except Exception as e:
                    print(f"處理題目 {idx} 時發生錯誤: {e}")
                    continue
                
        except KeyboardInterrupt:
            print("\n使用者中斷處理！")
            print("已儲存目前處理的結果，下次執行時會從中斷處繼續。")
        
        print(f"\n處理完成！")
        print(f"總題目數: {total_questions}")
        print(f"已處理: {processed}")
        print(f"跳過: {skipped}")
        print(f"成功匹配: {matched}")
        print(f"無匹配: {processed - skipped - matched}")
    
    def get_questions_to_delete(self) -> List[str]:
        """取得需要刪除的題目編號清單"""
        to_delete = []
        for result in self.results:
            if result['status'] in ['skipped', 'no_knowledge_points', 'no_match']:
                to_delete.append(result['ques_no'])
        return to_delete
    
    def generate_delete_report(self, output_path: str = "questions_to_delete.txt"):
        """生成需要刪除的題目報告"""
        to_delete = self.get_questions_to_delete()
        
        try:
            with open(output_path, 'w', encoding='utf-8') as f:
                f.write("需要刪除的題目編號清單\n")
                f.write("=" * 50 + "\n\n")
                
                # 按原因分組
                delete_reasons = {}
                for result in self.results:
                    if result['status'] in ['skipped', 'no_knowledge_points', 'no_match']:
                        reason = result['reason'] if result['reason'] else result['status']
                        if reason not in delete_reasons:
                            delete_reasons[reason] = []
                        delete_reasons[reason].append(result['ques_no'])
                
                for reason, question_nos in delete_reasons.items():
                    f.write(f"刪除原因: {reason}\n")
                    f.write(f"題目數量: {len(question_nos)}\n")
                    f.write("題目編號: " + ", ".join(question_nos) + "\n\n")
                
                f.write(f"總共需要刪除的題目數: {len(to_delete)}\n")
            
            print(f"刪除報告已儲存到: {output_path}")
            print(f"總共需要刪除 {len(to_delete)} 道題目")
            
        except Exception as e:
            print(f"生成刪除報告失敗: {e}")

def main():
    """主程式"""
    matcher = QuestionKnowledgePointMatcher()
    
    # 載入資料
    if not matcher.load_data():
        return
    
    # 處理題目
    matcher.process_questions(batch_size=5)  # 調整批次大小以控制 API 呼叫頻率
    
    # 生成刪除報告
    matcher.generate_delete_report()

if __name__ == "__main__":
    main() 