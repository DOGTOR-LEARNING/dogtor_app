"""
數據模型定義
"""
from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime


class ChatRequest(BaseModel):
    user_message: Optional[str] = None
    image_base64: Optional[str] = None
    subject: Optional[str] = None
    chapter: Optional[str] = None
    user_name: Optional[str] = None
    user_introduction: Optional[str] = None
    year_grade: Optional[str] = None


class User(BaseModel):
    user_id: str
    email: Optional[str] = None
    name: Optional[str] = None
    photo_url: Optional[str] = None
    created_at: Optional[str] = None
    nickname: Optional[str] = None
    year_grade: Optional[str] = None
    introduction: Optional[str] = None


class FriendRequest(BaseModel):
    requester_id: str
    addressee_id: str


class FriendResponse(BaseModel):
    request_id: str
    status: str  # accepted, rejected, blocked


class HeartCheckRequest(BaseModel):
    user_id: str


class HeartCheckResponse(BaseModel):
    success: bool
    hearts: int
    next_heart_in: Optional[str] = None


class ConsumeHeartRequest(BaseModel):
    user_id: str


class ConsumeHeartResponse(BaseModel):
    success: bool
    hearts: int


class MistakeBookRequest(BaseModel):
    user_id: Optional[str] = None
    summary: Optional[str] = None
    subject: Optional[str] = None
    chapter: Optional[str] = None
    difficulty: Optional[str] = None
    tag: Optional[str] = None
    description: Optional[str] = None
    answer: Optional[str] = None
    note: Optional[str] = None
    created_at: Optional[str] = None
    question_image_base64: Optional[str] = None
    answer_image_base64: Optional[str] = None


class MistakeBookResponse(BaseModel):
    status: str
    q_id: Optional[int] = None


class QuestionRequest(BaseModel):
    chapter: Optional[str] = None
    section: Optional[str] = None
    knowledge_points: Optional[str] = None
    user_id: Optional[str] = None
    level_id: Optional[str] = None


class QuestionResponse(BaseModel):
    success: bool
    questions: Optional[List[dict]] = None
    message: Optional[str] = None


class RecordAnswerRequest(BaseModel):
    user_id: str
    question_id: int
    is_correct: bool


class RecordAnswerResponse(BaseModel):
    success: bool
    message: str


class CompleteLevelRequest(BaseModel):
    user_id: str
    level_id: str
    stars: int
    ai_comment: Optional[str] = None


class RecordAnswerRequest(BaseModel):
    user_id: str
    question_id: int
    is_correct: bool


class QuestionRequest(BaseModel):
    user_id: str
    chapter: str
    section: str
    knowledge_points: str
    level_id: str


class QuestionResponse(BaseModel):
    success: bool
    questions: Optional[List[dict]] = None
    level_info: Optional[dict] = None
    message: Optional[str] = None


class RecordAnswerResponse(BaseModel):
    success: bool
    message: str


class CompleteLevelRequest(BaseModel):
    user_id: str
    level_id: str
    stars: int
    ai_comment: Optional[str] = None


class CompleteLevelResponse(BaseModel):
    success: bool
    message: str


class SearchUsersRequest(BaseModel):
    query: str
    current_user_id: str


class LearningReminderRequest(BaseModel):
    user_id: str
    message: Optional[str] = "你的朋友提醒你該學習了！"
    sender_id: Optional[str] = None


class TokenRegisterRequest(BaseModel):
    user_id: str
    token: str


class TestPushRequest(BaseModel):
    token: str
    title: Optional[str] = "Dogtor 通知"
    body: Optional[str] = "這是測試推播"


class ClassifyTextRequest(BaseModel):
    text: str


class ClassifyTextResponse(BaseModel):
    success: bool
    predicted_class: Optional[str] = None
    confidence: Optional[float] = None
    message: Optional[str] = None


class AnalyzeQuizRequest(BaseModel):
    user_id: str
    answers: List[dict]
    correct_count: int
    total_count: int


class ClassifyTextRequest(BaseModel):
    text: str


class ClassifyTextResponse(BaseModel):
    success: bool
    predictions: Optional[List[dict]] = None
    confidence: Optional[float] = None
    message: Optional[str] = None


class AnalyzeQuizResponse(BaseModel):
    success: bool
    ai_comment: Optional[str] = None
    message: Optional[str] = None


class SearchUsersRequest(BaseModel):
    search_term: str
    current_user_id: str


class UserStatsRequest(BaseModel):
    user_id: str
    time_range: Optional[str] = "week"


class MonthlyProgressRequest(BaseModel):
    user_id: str
    year: int
    month: int


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
