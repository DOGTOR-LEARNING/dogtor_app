import csv

text_a = ''
text_b = ''

i = 1

with open('output.txt', 'r', encoding='utf-8') as file:
    lines = file.readlines()

# 移除換行符號，確保每一行都是一個完整的字串
lines = [line.strip() for line in lines]

with open('output.txt', 'r', encoding='utf-8') as file:
    lines = file.readlines()

for row in lines:
        #print(type(row))
        #print(row)
        a,b = row.split(',')
        text_a += a
        print(i, a)
        text_a += "\n"
        text_b += b
        #text_b += "\n"
        print(i, b[:10])

        i += 1

with open("knowledge_points.txt", "w", encoding="utf-8") as file:
    file.write(text_a)

with open("section_summary.txt", "w", encoding="utf-8") as file:
    file.write(text_b)

print("文字已成功存入")

'''
with open('output.txt', newline='', encoding='utf-8') as csvfile:
    reader = csv.reader(csvfile)
    for row in reader:
        #print(type(row))
        #print(row)
        a,b = row[0], row[1]
        text_a += a
        print(i, a)
        text_a += "\n"
        text_b += b
        text_b += "\n"
        print(i, b[:10])

        i += 1

with open("knowledge_points.txt", "w", encoding="utf-8") as file:
    file.write(text_a)

with open("section_summary.txt", "w", encoding="utf-8") as file:
    file.write(text_b)

print("文字已成功存入")
'''