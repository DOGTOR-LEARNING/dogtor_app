import torch
import torch.nn as nn
import re
from typing import List, Optional
import json

class TextCNN(nn.Module):
    def __init__(self, vocab_size, embed_size, num_classes, num_filters=100, filter_sizes=[3, 4, 5], dropout=0.5):
        super(TextCNN, self).__init__()
        self.embedding = nn.Embedding(vocab_size, embed_size)
        self.convs = nn.ModuleList([
            nn.Conv1d(embed_size, num_filters, filter_size)
            for filter_size in filter_sizes
        ])
        self.dropout = nn.Dropout(dropout)
        self.fc = nn.Linear(len(filter_sizes) * num_filters, num_classes)
        
    def forward(self, x):
        x = self.embedding(x)  # (batch_size, seq_len, embed_size)
        x = x.permute(0, 2, 1)  # (batch_size, embed_size, seq_len)
        
        conv_outputs = []
        for conv in self.convs:
            conv_out = torch.relu(conv(x))  # (batch_size, num_filters, new_seq_len)
            pooled = torch.max_pool1d(conv_out, conv_out.size(2))  # (batch_size, num_filters, 1)
            conv_outputs.append(pooled.squeeze(2))  # (batch_size, num_filters)
        
        x = torch.cat(conv_outputs, dim=1)  # (batch_size, len(filter_sizes) * num_filters)
        x = self.dropout(x)
        x = self.fc(x)
        return x

def preprocess_text(text: str, vocab_to_idx: Optional[dict] = None, max_length: int = 512) -> torch.Tensor:
    """預處理文本"""
    # 基本文本清理
    text = text.lower().strip()
    # 移除特殊字符，保留中文、英文和數字
    text = re.sub(r'[^\u4e00-\u9fff\w\s]', ' ', text)
    
    # 簡單的詞彙化
    words = text.split()
    
    # 如果沒有詞彙表，創建一個簡單的字符級索引
    if vocab_to_idx is None:
        # 字符級處理
        chars = list(text.replace(' ', ''))
        # 創建簡單的字符到索引映射
        unique_chars = set(chars)
        vocab_to_idx = {char: idx + 1 for idx, char in enumerate(unique_chars)}
        vocab_to_idx['<UNK>'] = 0
        
        indices = [vocab_to_idx.get(char, 0) for char in chars]
    else:
        # 詞級處理
        indices = [vocab_to_idx.get(word, vocab_to_idx.get('<UNK>', 0)) for word in words]
    
    # 截斷或填充到固定長度
    if len(indices) > max_length:
        indices = indices[:max_length]
    else:
        indices.extend([0] * (max_length - len(indices)))
        
    return torch.tensor(indices, dtype=torch.long).unsqueeze(0)

def test_model(model_path: str, test_texts: List[str]):
    """測試模型"""
    print(f"正在加載模型: {model_path}")
    
    try:
        # 加載模型檢查點
        checkpoint = torch.load(model_path, map_location='cpu')
        print("\n=== 模型檢查點信息 ===")
        
        # 從檢查點獲取模型參數
        model_state = checkpoint.get('model_state_dict', checkpoint)
        vocab_size = checkpoint.get('vocab_size', 10000)
        embed_size = checkpoint.get('embed_size', 100)
        num_classes = checkpoint.get('num_classes', 50)
        
        # 如果檢查點中沒有這些參數，嘗試從模型狀態推斷
        if 'vocab_size' not in checkpoint:
            vocab_size = model_state['embedding.weight'].shape[0]
        if 'embed_size' not in checkpoint:
            embed_size = model_state['embedding.weight'].shape[1]
        if 'num_classes' not in checkpoint:
            num_classes = model_state['fc.weight'].shape[0]
            
        print(f"詞彙表大小: {vocab_size}")
        print(f"嵌入維度: {embed_size}")
        print(f"類別數量: {num_classes}")
        
        # 檢查是否有詞彙表和標籤映射
        vocab_to_idx = checkpoint.get('vocab_to_idx', None)
        idx_to_label = checkpoint.get('idx_to_label', None)
        
        if vocab_to_idx:
            print(f"\n詞彙表大小: {len(vocab_to_idx)}")
            print("詞彙表示例（前10個）:")
            for i, (word, idx) in enumerate(list(vocab_to_idx.items())[:10]):
                print(f"  {word}: {idx}")
        
        if idx_to_label:
            print(f"\n標籤映射:")
            for idx, label in idx_to_label.items():
                print(f"  {idx}: {label}")
        
        # 創建模型實例
        model = TextCNN(
            vocab_size=vocab_size,
            embed_size=embed_size,
            num_classes=num_classes
        )
        
        # 加載模型權重
        model.load_state_dict(model_state)
        model.eval()
        print("\n✅ 模型加載成功!")
        
        # 測試樣本文本
        print("\n=== 測試樣本 ===")
        for text in test_texts:
            print(f"\n輸入文本: {text}")
            
            # 預處理文本
            processed_text = preprocess_text(text, vocab_to_idx)
            
            # 模型推理
            with torch.no_grad():
                outputs = model(processed_text)
                probabilities = torch.softmax(outputs, dim=1)
                predicted_idx = torch.argmax(probabilities, dim=1).item()
                confidence = probabilities[0][predicted_idx].item()
            
            # 獲取預測標籤
            if idx_to_label and predicted_idx < len(idx_to_label):
                predicted_label = idx_to_label[predicted_idx]
            else:
                predicted_label = f"類別_{predicted_idx}"
            
            print(f"預測結果: {predicted_label}")
            print(f"信心度: {confidence:.4f}")
            
            # 獲取前3個預測結果
            top3_probs, top3_indices = torch.topk(probabilities[0], min(3, probabilities.shape[1]))
            print("\n前三個預測結果:")
            for i, (prob, idx) in enumerate(zip(top3_probs, top3_indices)):
                label = idx_to_label[idx.item()] if idx_to_label and idx.item() < len(idx_to_label) else f"類別_{idx.item()}"
                print(f"  {i+1}. {label} ({prob.item():.4f})")
        
    except Exception as e:
        print(f"\n❌ 錯誤: {str(e)}")
        import traceback
        print(traceback.format_exc())

if __name__ == "__main__":
    # 模型文件路徑
    model_path = "best_textcnn.pt"  # 請修改為您的模型文件路徑
    
    # 測試文本
    test_texts = [
        "二次函數的頂點公式是什麼？在座標平面上，二次函數圖形的頂點代表什麼意義？",
        "三角函數的基本性質有哪些？正弦和餘弦函數的關係是什麼？",
        "因式分解的基本方法有哪些？如何用十字相乘法進行因式分解？",
        "指數函數和對數函數的關係是什麼？它們的圖形有什麼特點？"
    ]
    
    # 運行測試
    test_model(model_path, test_texts) 