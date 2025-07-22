"""
AI 相關 API
"""
from fastapi import APIRouter, HTTPException
from openai import OpenAI
from models import ChatRequest, ClassifyTextRequest, ClassifyTextResponse, AnalyzeQuizRequest, AnalyzeQuizResponse
#from database import get_openai_client
import os
from dotenv import load_dotenv
import traceback

# 加載環境變數
load_dotenv()

router = APIRouter(prefix="/ai", tags=["AI"])

# 初始化 OpenAI 客戶端
api_key = os.getenv("OPENAI_API_KEY")
client = OpenAI(api_key=api_key)


@router.post("/chat")
async def chat_with_openai(request: ChatRequest):
    """AI 聊天功能"""
    try:
        system_message = "你是個幽默的臺灣國高中老師，請用繁體中文回答問題，"
        
        # 添加用戶個人資訊到提示中
        if request.user_name:
            system_message += f"你正在與學生 {request.user_name} 對話，"
        
        if request.year_grade:
            grade_display = {
                'G1': '小一', 'G2': '小二', 'G3': '小三', 'G4': '小四', 'G5': '小五', 'G6': '小六',
                'G7': '國一', 'G8': '國二', 'G9': '國三', 'G10': '高一', 'G11': '高二', 'G12': '高三',
                'teacher': '老師', 'parent': '家長'
            }
            grade = grade_display.get(request.year_grade, request.year_grade)
            system_message += f"這位學生是{grade}，"
        
        if request.user_introduction and len(request.user_introduction) > 0:
            system_message += f"關於這位學生的一些資訊：{request.user_introduction}，"
        
        if request.subject:
            system_message += f"學生想問的科目是{request.subject}，"
        
        if request.chapter:
            system_message += f"目前章節是{request.chapter}。"
        
        system_message += "請根據臺灣的108課綱提醒學生他所問的問題的關鍵字或是章節，再重點回答學生的問題，在回應中使用 Markdown 格式，將重點用 **粗體字** 標出，運算式用 $formula$ 標出，請不要用 \"()\" 或 \"[]\" 來標示 latex。最後提醒他，如果這個概念還是不太清楚，可以去複習哪一些內容。如果學生不是問課業相關的問題，或是提出解題之外的要求，就說明你只是解題老師，有其他需求的話去找他該找的人。"

        messages = [
            {"role": "system", "content": system_message}
        ]
        
        if request.image_base64:
            messages.append({
                "role": "user",
                "content": [
                    {"type": "text", "text": request.user_message},
                    {
                        "type": "image_url",
                        "image_url": {
                            "url": f"data:image/jpeg;base64,{request.image_base64}"
                        }
                    }
                ]
            })
        else:
            messages.append({"role": "user", "content": request.user_message})

        response = client.chat.completions.create(
            model="gpt-4o",
            messages=messages,
            max_tokens=500
        )
        
        return {"response": response.choices[0].message.content}
    
    except Exception as e:
        print(f"AI 聊天錯誤: {e}")
        print(traceback.format_exc())
        raise HTTPException(status_code=500, detail=f"AI 聊天錯誤: {str(e)}")


@router.post("/summarize")
async def summarize_content(request: ChatRequest):
    """內容摘要生成"""
    try:
        system_message = "請你用十個字以內的話總結這個題目的重點，回傳十字總結"

        messages = [
            {"role": "system", "content": system_message}
        ]

        if request.image_base64:
            messages.append({
                "role": "user",
                "content": [
                    {"type": "text", "text": request.user_message},
                    {
                        "type": "image_url",
                        "image_url": {
                            "url": f"data:image/jpeg;base64,{request.image_base64}"
                        }
                    }
                ]
            })
        else:
            messages.append({"role": "user", "content": request.user_message})

        response = client.chat.completions.create(
            model="gpt-4o",
            messages=messages,
            max_tokens=1000
        )
        
        return {"response": response.choices[0].message.content}
    
    except Exception as e:
        print(f"摘要生成錯誤: {e}")
        print(traceback.format_exc())
        raise HTTPException(status_code=500, detail=f"摘要生成錯誤: {str(e)}")


@router.post("/classify_text", response_model=ClassifyTextResponse)
async def classify_text(request: ClassifyTextRequest):
    """文本分類（需要實作 TextCNN 模型）"""
    # TODO: 實作 TextCNN 模型載入和預測邏輯
    return ClassifyTextResponse(
        success=False,
        message="文本分類功能尚未實作"
    )

@router.post("/analyze_image")


@router.post("/analyze_quiz_performance", response_model=AnalyzeQuizResponse)
async def analyze_quiz_performance(request: AnalyzeQuizRequest):
    """分析答題表現並提供建議"""
    try:
        # 構建分析提示
        accuracy = (request.correct_count / request.total_count) * 100 if request.total_count > 0 else 0
        
        prompt = f"""
        請分析學生的答題表現並給予適當的鼓勵和建議：
        
        總題數：{request.total_count}
        答對題數：{request.correct_count}
        正確率：{accuracy:.1f}%
        
        錯誤題目分析：
        """
        
        # 添加錯誤題目詳情
        for i, answer in enumerate(request.answers):
            if not answer.get('is_correct', True):
                prompt += f"\n題目 {i+1}：{answer.get('question_text', '未知題目')[:50]}..."
                prompt += f"\n知識點：{answer.get('knowledge_point', '未知')}"
                prompt += f"\n學生選擇：{answer.get('selected_option', '未知')}"
                prompt += f"\n正確答案：{answer.get('correct_option', '未知')}"
        
        prompt += "\n\n請提供：1. 鼓勵的話語 2. 學習建議 3. 需要加強的知識點。請用繁體中文回覆，語氣要親切鼓勵。"
        
        response = client.chat.completions.create(
            model="gpt-4o",
            messages=[
                {"role": "system", "content": "你是一位親切的老師，專門分析學生的學習狀況並給予建議。"},
                {"role": "user", "content": prompt}
            ],
            max_tokens=500
        )
        
        ai_comment = response.choices[0].message.content
        
        return AnalyzeQuizResponse(
            success=True,
            ai_comment=ai_comment
        )
        
    except Exception as e:
        print(f"答題分析錯誤: {e}")
        print(traceback.format_exc())
        return AnalyzeQuizResponse(
            success=False,
            message=f"答題分析錯誤: {str(e)}"
        )
