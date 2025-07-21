"""
數據模型定義 - 包含完整的範例和欄位說明用於 Swagger UI
"""
from pydantic import BaseModel, Field, ConfigDict
from typing import Optional, List, Dict, Any
from datetime import datetime


class ChatRequest(BaseModel):
    """AI 聊天請求模型"""
    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "user_message": "請幫我解釋牛頓第一定律",
                "subject": "物理",
                "chapter": "力學",
                "user_name": "小明",
                "year_grade": "G11"
            }
        }
    )
    
    user_message: Optional[str] = Field(
        None, 
        description="用戶輸入的文字訊息",
        examples=["請幫我解釋牛頓第一定律", "什麼是二次函數？"]
    )
    image_base64: Optional[str] = Field(
        None, 
        description="Base64 編碼的圖片數據",
        examples=["data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQ..."]
    )
    subject: Optional[str] = Field(
        None, 
        description="科目名稱",
        examples=["物理", "數學", "化學"]
    )
    chapter: Optional[str] = Field(
        None, 
        description="章節名稱", 
        examples=["力學", "二次函數", "有機化學"]
    )
    user_name: Optional[str] = Field(
        None, 
        description="用戶姓名",
        examples=["小明", "小華"]
    )
    user_introduction: Optional[str] = Field(
        None, 
        description="用戶自我介紹",
        examples=["我是高二學生，對物理有興趣但數學基礎較弱"]
    )
    year_grade: Optional[str] = Field(
        None, 
        description="年級",
        examples=["G11", "G12", "G10"]
    )


class ChatResponse(BaseModel):
    """AI 聊天回應模型"""
    response: str = Field(
        description="AI 生成的回應內容",
        example="**牛頓第一定律**（慣性定律）指出：物體在沒有外力作用時，會保持靜止或等速直線運動的狀態..."
    )

    class Config:
        schema_extra = {
            "example": {
                "response": "**牛頓第一定律**（慣性定律）指出：物體在沒有外力作用時，會保持靜止或等速直線運動的狀態。這個定律說明了物體具有慣性，傾向於維持其現有的運動狀態。"
            }
        }


class User(BaseModel):
    """用戶資訊模型"""
    user_id: str = Field(description="用戶唯一識別碼", example="user_12345")
    email: Optional[str] = Field(None, description="電子郵件", example="user@example.com")
    name: Optional[str] = Field(None, description="用戶姓名", example="王小明")
    photo_url: Optional[str] = Field(None, description="頭像 URL", example="https://example.com/avatar.jpg")
    created_at: Optional[str] = Field(None, description="建立時間", example="2025-07-21T10:30:00Z")
    nickname: Optional[str] = Field(None, description="暱稱", example="小明")
    year_grade: Optional[str] = Field(None, description="年級", example="G11")
    introduction: Optional[str] = Field(None, description="自我介紹", example="我是高二學生，喜歡數學和物理")

    class Config:
        schema_extra = {
            "example": {
                "user_id": "user_12345",
                "email": "student@example.com",
                "name": "王小明",
                "nickname": "小明",
                "year_grade": "G11",
                "introduction": "我是高二學生，喜歡數學和物理"
            }
        }


class FriendRequest(BaseModel):
    """好友請求模型"""
    requester_id: str = Field(description="請求者用戶 ID", example="user_12345")
    addressee_id: str = Field(description="接收者用戶 ID", example="user_67890")

    class Config:
        schema_extra = {
            "example": {
                "requester_id": "user_12345",
                "addressee_id": "user_67890"
            }
        }


class FriendResponse(BaseModel):
    """好友請求回應模型"""
    request_id: str = Field(description="請求 ID", example="req_123")
    status: str = Field(description="回應狀態", example="accepted", enum=["accepted", "rejected", "blocked"])

    class Config:
        schema_extra = {
            "example": {
                "request_id": "req_123",
                "status": "accepted"
            }
        }


class HeartCheckRequest(BaseModel):
    """愛心檢查請求模型"""
    user_id: str = Field(description="用戶 ID", example="user_12345")

    class Config:
        schema_extra = {
            "example": {
                "user_id": "user_12345"
            }
        }


class HeartCheckResponse(BaseModel):
    """愛心檢查回應模型"""
    success: bool = Field(description="是否成功", example=True)
    hearts: int = Field(description="當前愛心數量", example=3)
    next_heart_in: Optional[str] = Field(None, description="下一顆愛心恢復時間", example="2025-07-21T14:30:00Z")

    class Config:
        schema_extra = {
            "example": {
                "success": True,
                "hearts": 3,
                "next_heart_in": "2025-07-21T14:30:00Z"
            }
        }


class ConsumeHeartRequest(BaseModel):
    """愛心消耗請求模型"""
    user_id: str = Field(description="用戶 ID", example="user_12345")
    hearts_to_consume: int = Field(1, description="要消耗的愛心數量", example=1)

    class Config:
        schema_extra = {
            "example": {
                "user_id": "user_12345",
                "hearts_to_consume": 1
            }
        }


class ConsumeHeartResponse(BaseModel):
    """愛心消耗回應模型"""
    success: bool = Field(description="是否成功", example=True)
    hearts: int = Field(description="剩餘愛心數量", example=2)
    message: str = Field(description="回應訊息", example="愛心消耗成功")

    class Config:
        schema_extra = {
            "example": {
                "success": True,
                "hearts": 2,
                "message": "愛心消耗成功"
            }
        }


class MistakeBookRequest(BaseModel):
    """錯題本請求模型"""
    user_id: Optional[str] = Field(None, description="用戶 ID", example="user_12345")
    summary: Optional[str] = Field(None, description="題目摘要", example="二次函數的頂點公式")
    subject: Optional[str] = Field(None, description="科目", example="數學")
    chapter: Optional[str] = Field(None, description="章節", example="二次函數")
    difficulty: Optional[str] = Field(None, description="難度", example="中等")
    tag: Optional[str] = Field(None, description="標籤", example="函數")
    description: Optional[str] = Field(None, description="題目描述", example="求 f(x) = x² - 4x + 3 的頂點坐標")
    answer: Optional[str] = Field(None, description="答案", example="頂點坐標為 (2, -1)")
    note: Optional[str] = Field(None, description="筆記", example="使用配方法或頂點公式")
    created_at: Optional[str] = Field(None, description="建立時間", example="2025-07-21T10:30:00Z")
    question_image_base64: Optional[str] = Field(None, description="題目圖片 Base64", example="data:image/jpeg;base64,...")
    answer_image_base64: Optional[str] = Field(None, description="解答圖片 Base64", example="data:image/jpeg;base64,...")

    class Config:
        schema_extra = {
            "example": {
                "user_id": "user_12345",
                "summary": "二次函數的頂點公式",
                "subject": "數學",
                "chapter": "二次函數",
                "difficulty": "中等",
                "description": "求 f(x) = x² - 4x + 3 的頂點坐標",
                "answer": "頂點坐標為 (2, -1)",
                "note": "使用配方法或頂點公式"
            }
        }


class MistakeBookResponse(BaseModel):
    """錯題本回應模型"""
    status: str = Field(description="狀態", example="success")
    q_id: Optional[int] = Field(None, description="題目 ID", example=123)
    message: Optional[str] = Field(None, description="回應訊息", example="錯題新增成功")

    class Config:
        schema_extra = {
            "example": {
                "status": "success",
                "q_id": 123,
                "message": "錯題新增成功"
            }
        }


# 這些舊定義已被下方增強版本替代，已移除


class RecordAnswerRequest(BaseModel):
    """記錄答題請求模型"""
    user_id: str = Field(description="用戶 ID", example="user_12345")
    question_id: int = Field(description="題目 ID", example=101)
    is_correct: bool = Field(description="是否正確", example=True)

    class Config:
        schema_extra = {
            "example": {
                "user_id": "user_12345",
                "question_id": 101,
                "is_correct": True
            }
        }


class QuestionRequest(BaseModel):
    """題目請求模型"""
    user_id: str = Field(description="用戶 ID", example="user_12345")
    chapter: str = Field(description="章節", example="二次函數")
    section: str = Field(description="小節", example="頂點公式")
    knowledge_points: str = Field(description="知識點", example="配方法")
    level_id: str = Field(description="關卡 ID", example="level_001")

    class Config:
        schema_extra = {
            "example": {
                "user_id": "user_12345",
                "chapter": "二次函數",
                "section": "頂點公式",
                "knowledge_points": "配方法",
                "level_id": "level_001"
            }
        }


class QuestionResponse(BaseModel):
    """題目回應模型"""
    success: bool = Field(description="是否成功", example=True)
    questions: Optional[List[dict]] = Field(
        None,
        description="題目列表",
        example=[
            {
                "id": 101,
                "question_text": "求 f(x) = x² - 4x + 3 的頂點坐標",
                "options": ["(2, -1)", "(2, 1)", "(-2, -1)", "(-2, 1)"],
                "correct_answer": "A",
                "difficulty": "中等"
            }
        ]
    )
    level_info: Optional[dict] = Field(
        None,
        description="關卡資訊",
        example={
            "level_id": "level_001",
            "level_name": "二次函數基礎",
            "total_questions": 5,
            "required_score": 80
        }
    )
    message: Optional[str] = Field(None, description="回應訊息", example="題目獲取成功")

    class Config:
        schema_extra = {
            "example": {
                "success": True,
                "questions": [
                    {
                        "id": 101,
                        "question_text": "求 f(x) = x² - 4x + 3 的頂點坐標",
                        "options": ["(2, -1)", "(2, 1)", "(-2, -1)", "(-2, 1)"],
                        "correct_answer": "A",
                        "difficulty": "中等"
                    }
                ],
                "level_info": {
                    "level_id": "level_001",
                    "level_name": "二次函數基礎",
                    "total_questions": 5,
                    "required_score": 80
                },
                "message": "題目獲取成功"
            }
        }


class RecordAnswerResponse(BaseModel):
    """記錄答題回應模型"""
    success: bool = Field(description="是否成功", example=True)
    message: str = Field(description="回應訊息", example="答題記錄成功")

    class Config:
        schema_extra = {
            "example": {
                "success": True,
                "message": "答題記錄成功"
            }
        }


class CompleteLevelRequest(BaseModel):
    """完成關卡請求模型"""
    user_id: str = Field(description="用戶 ID", example="user_12345")
    level_id: str = Field(description="關卡 ID", example="level_001")
    stars: int = Field(description="獲得星數", example=3, ge=0, le=3)
    ai_comment: Optional[str] = Field(None, description="AI 評語", example="表現優秀！完全掌握了二次函數的概念")

    class Config:
        schema_extra = {
            "example": {
                "user_id": "user_12345",
                "level_id": "level_001",
                "stars": 3,
                "ai_comment": "表現優秀！完全掌握了二次函數的概念"
            }
        }


class CompleteLevelResponse(BaseModel):
    """完成關卡回應模型"""
    success: bool = Field(description="是否成功", example=True)
    message: str = Field(description="回應訊息", example="關卡完成記錄成功")

    class Config:
        schema_extra = {
            "example": {
                "success": True,
                "message": "關卡完成記錄成功"
            }
        }


class SearchUsersRequest(BaseModel):
    """搜尋用戶請求模型"""
    query: str = Field(description="搜尋關鍵字", example="王小明")
    current_user_id: str = Field(description="當前用戶 ID", example="user_12345")

    class Config:
        schema_extra = {
            "example": {
                "query": "王小明",
                "current_user_id": "user_12345"
            }
        }


class LearningReminderRequest(BaseModel):
    """學習提醒請求模型"""
    user_id: str = Field(description="被提醒的用戶 ID", example="user_67890")
    message: Optional[str] = Field(
        "你的朋友提醒你該學習了！",
        description="提醒訊息",
        example="該複習數學了！"
    )
    sender_id: Optional[str] = Field(None, description="發送者 ID", example="user_12345")

    class Config:
        schema_extra = {
            "example": {
                "user_id": "user_67890",
                "message": "該複習數學了！",
                "sender_id": "user_12345"
            }
        }


class TokenRegisterRequest(BaseModel):
    """推播 Token 註冊請求模型"""
    user_id: str = Field(description="用戶 ID", example="user_12345")
    token: str = Field(description="Firebase 推播 Token", example="fGH3k2m1...")

    class Config:
        schema_extra = {
            "example": {
                "user_id": "user_12345",
                "token": "fGH3k2m1L8n9P4q7R2t5W8x1Z4c6V9b2"
            }
        }


class TestPushRequest(BaseModel):
    """測試推播請求模型"""
    token: str = Field(description="Firebase 推播 Token", example="fGH3k2m1...")
    title: Optional[str] = Field("Dogtor 通知", description="推播標題", example="學習提醒")
    body: Optional[str] = Field("這是測試推播", description="推播內容", example="您有新的學習任務待完成")

    class Config:
        schema_extra = {
            "example": {
                "token": "fGH3k2m1L8n9P4q7R2t5W8x1Z4c6V9b2",
                "title": "學習提醒",
                "body": "您有新的學習任務待完成"
            }
        }


class ClassifyTextRequest(BaseModel):
    """文本分類請求模型"""
    text: str = Field(description="待分類的文本", example="解一元二次方程式 x² - 5x + 6 = 0")

    class Config:
        schema_extra = {
            "example": {
                "text": "解一元二次方程式 x² - 5x + 6 = 0"
            }
        }


class ClassifyTextResponse(BaseModel):
    """文本分類回應模型"""
    success: bool = Field(description="是否成功", example=True)
    predicted_class: Optional[str] = Field(None, description="預測類別", example="數學")
    confidence: Optional[float] = Field(None, description="信心度", example=0.95, ge=0, le=1)
    message: Optional[str] = Field(None, description="回應訊息", example="分類成功")

    class Config:
        schema_extra = {
            "example": {
                "success": True,
                "predicted_class": "數學",
                "confidence": 0.95,
                "message": "分類成功"
            }
        }


class AnalyzeQuizRequest(BaseModel):
    """測驗分析請求模型"""
    user_id: str = Field(description="用戶 ID", example="user_12345")
    answers: List[dict] = Field(
        description="答題記錄",
        example=[
            {"question_id": 101, "user_answer": "A", "correct_answer": "A", "is_correct": True},
            {"question_id": 102, "user_answer": "B", "correct_answer": "C", "is_correct": False}
        ]
    )
    correct_count: int = Field(description="答對題數", example=8, ge=0)
    total_count: int = Field(description="總題數", example=10, ge=0)

    class Config:
        schema_extra = {
            "example": {
                "user_id": "user_12345",
                "answers": [
                    {"question_id": 101, "user_answer": "A", "correct_answer": "A", "is_correct": True},
                    {"question_id": 102, "user_answer": "B", "correct_answer": "C", "is_correct": False}
                ],
                "correct_count": 8,
                "total_count": 10
            }
        }


class AnalyzeQuizResponse(BaseModel):
    """測驗分析回應模型"""
    success: bool = Field(description="是否成功", example=True)
    ai_comment: Optional[str] = Field(
        None,
        description="AI 評語",
        example="表現良好！建議加強練習二次函數的應用題型"
    )
    message: Optional[str] = Field(None, description="回應訊息", example="分析完成")

    class Config:
        schema_extra = {
            "example": {
                "success": True,
                "ai_comment": "表現良好！建議加強練習二次函數的應用題型",
                "message": "分析完成"
            }
        }


class SearchUsersRequest(BaseModel):
    """搜尋用戶請求模型（重複定義，待整合）"""
    search_term: str = Field(description="搜尋關鍵字", example="李小華")
    current_user_id: str = Field(description="當前用戶 ID", example="user_12345")

    class Config:
        schema_extra = {
            "example": {
                "search_term": "李小華",
                "current_user_id": "user_12345"
            }
        }


class UserStatsRequest(BaseModel):
    """用戶統計請求模型"""
    user_id: str = Field(description="用戶 ID", example="user_12345")
    time_range: Optional[str] = Field("week", description="時間範圍", example="week")

    class Config:
        schema_extra = {
            "example": {
                "user_id": "user_12345",
                "time_range": "week"
            }
        }


class MonthlyProgressRequest(BaseModel):
    """月度進度請求模型"""
    user_id: str = Field(description="用戶 ID", examples=["user_12345"])

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "user_id": "user_12345"
            }
        }
    )

    year: int
    month: int


# 新增：用戶在線狀態相關模型
class UserOnlineStatusRequest(BaseModel):
    """用戶在線狀態請求模型"""
    user_id: str = Field(description="用戶 ID", examples=["user_12345"])
    
    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "user_id": "user_12345"
            }
        }
    )


class UpdateOnlineStatusRequest(BaseModel):
    """更新在線狀態請求模型"""
    user_id: str = Field(description="用戶 ID", examples=["user_12345"])
    is_online: bool = Field(description="是否在線", examples=[True, False])
    
    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "user_id": "user_12345",
                "is_online": True
            }
        }
    )


# 新增：對戰模式相關模型
class StartBattleRequest(BaseModel):
    """發起對戰請求模型"""
    challenger_id: str = Field(description="發起者用戶 ID", examples=["user_12345"])
    opponent_id: str = Field(description="對手用戶 ID", examples=["user_67890"])
    chapter: str = Field(description="選擇的章節", examples=["二次函數", "力學"])
    subject: str = Field(description="科目", examples=["數學", "物理"])
    
    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "challenger_id": "user_12345",
                "opponent_id": "user_67890",
                "chapter": "二次函數",
                "subject": "數學"
            }
        }
    )


class BattleResponse(BaseModel):
    """對戰回應模型"""
    success: bool = Field(description="是否成功", examples=[True, False])
    battle_id: Optional[str] = Field(None, description="對戰 ID", examples=["battle_123"])
    message: str = Field(description="回應訊息", examples=["對戰房間已建立", "發起對戰失敗"])
    
    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "success": True,
                "battle_id": "battle_123",
                "message": "對戰房間已建立"
            }
        }
    )


class BattleQuestionRequest(BaseModel):
    """對戰題目請求模型"""
    battle_id: str = Field(description="對戰 ID", examples=["battle_123"])
    
    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "battle_id": "battle_123"
            }
        }
    )


class BattleAnswerRequest(BaseModel):
    """對戰答題請求模型"""
    battle_id: str = Field(description="對戰 ID", examples=["battle_123"])
    user_id: str = Field(description="用戶 ID", examples=["user_12345"])
    question_id: int = Field(description="題目 ID", examples=[101])
    answer: str = Field(description="選擇的答案", examples=["A", "B", "C", "D"])
    answer_time: float = Field(description="答題時間（秒）", examples=[3.5, 8.2])
    
    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "battle_id": "battle_123",
                "user_id": "user_12345",
                "question_id": 101,
                "answer": "A",
                "answer_time": 3.5
            }
        }
    )


class BattleResultRequest(BaseModel):
    """對戰結果請求模型"""
    battle_id: str = Field(description="對戰 ID", examples=["battle_123"])
    
    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "battle_id": "battle_123"
            }
        }
    )


class BattleResultResponse(BaseModel):
    """對戰結果回應模型"""
    success: bool = Field(description="是否成功", examples=[True])
    challenger_score: int = Field(description="發起者分數", examples=[850])
    opponent_score: int = Field(description="對手分數", examples=[720])
    winner_id: Optional[str] = Field(None, description="獲勝者 ID", examples=["user_12345"])
    battle_summary: Dict[str, Any] = Field(description="對戰摘要", examples=[{}])
    
    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "success": True,
                "challenger_score": 850,
                "opponent_score": 720,
                "winner_id": "user_12345",
                "battle_summary": {
                    "total_questions": 5,
                    "challenger_correct": 4,
                    "opponent_correct": 3,
                    "battle_duration": 180.5
                }
            }
        }
    )


class SubjectAbilitiesRequest(BaseModel):
    user_id: str


class LearningDaysResponse(BaseModel):
    learning_days: int
    streak_days: int


class PushNotificationRequest(BaseModel):
    title: str
    body: str
    token: Optional[str] = None
    user_id: Optional[str] = None


class LearningReminderRequest(BaseModel):
    user_id: str
    subject: str
    chapter: str
    difficulty_level: str


class RegisterTokenRequest(BaseModel):
    user_id: str
    token: str


class ImportKnowledgePointsRequest(BaseModel):
    csv_data: str
    subject: str


class StandardResponse(BaseModel):
    success: bool
    message: str
    data: Optional[dict] = None
