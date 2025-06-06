import torch
import torch.nn as nn
import re
from typing import List, Optional
import json
from transformers import BertTokenizerFast

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

from transformers import BertTokenizerFast

def test_model(model_path: str, test_texts: List[str]):
    print(f"正在加載模型: {model_path}")
    
    try:
        # 加載 BERT tokenizer
        tokenizer = BertTokenizerFast.from_pretrained('bert-base-uncased')
        
        # 加載模型檢查點
        checkpoint = torch.load(model_path, map_location='cpu')
        
        # 從檢查點獲取模型參數
        model_state = checkpoint.get('model_state_dict', checkpoint)
        vocab_size = tokenizer.vocab_size
        embed_size = 300  # 與訓練時保持一致
        num_classes = model_state['fc.weight'].shape[0]
        
        print("\n=== 模型檢查點信息 ===")
        print(f"詞彙表大小: {vocab_size}")
        print(f"嵌入維度: {embed_size}")
        print(f"類別數量: {num_classes}")
        
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
            
            # 使用 BERT tokenizer 處理文本
            encoding = tokenizer(
                text,
                add_special_tokens=True,
                max_length=128,
                padding="max_length",
                truncation=True,
                return_tensors="pt"
            )
            input_ids = encoding['input_ids']
            
            # 模型推理
            with torch.no_grad():
                outputs = model(input_ids)
                probabilities = torch.softmax(outputs, dim=1)
                predicted_idx = torch.argmax(probabilities, dim=1).item()
                confidence = probabilities[0][predicted_idx].item()
            
            # 獲取預測標籤
            predicted_label = f"類別_{predicted_idx}"
            print(f"預測結果: {predicted_label}")
            print(f"信心度: {confidence:.4f}")
            
            # 獲取前3個預測結果
            top3_probs, top3_indices = torch.topk(probabilities[0], min(3, probabilities.shape[1]))
            print("\n前三個預測結果:")
            for i, (prob, idx) in enumerate(zip(top3_probs, top3_indices)):
                label = f"類別_{idx.item()}"
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
        "人體器官有哪些？"
    ]
    
    # 運行測試
    test_model(model_path, test_texts) 