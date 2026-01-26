#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
サンプルPDFドキュメント生成スクリプト（図表入りバージョン）
Cortex Search（RAG）デモ用の内部規定・商品説明書PDFを生成
"""

from fpdf import FPDF
from fpdf.table import TableBordersLayout
import os

# 出力先ディレクトリ
OUTPUT_DIR = os.path.join(os.path.dirname(__file__), "sample_docs")
os.makedirs(OUTPUT_DIR, exist_ok=True)


class JapanesePDF(FPDF):
    """日本語対応PDF生成クラス（図表対応版）"""
    
    def __init__(self):
        super().__init__()
        # 日本語フォントの追加
        self.add_font("NotoSansJP", "", "/System/Library/Fonts/ヒラギノ角ゴシック W3.ttc")
        self.add_font("NotoSansJP", "B", "/System/Library/Fonts/ヒラギノ角ゴシック W6.ttc")
        self.set_auto_page_break(auto=True, margin=15)
    
    def header(self):
        if hasattr(self, 'doc_title') and self.doc_title:
            self.set_font("NotoSansJP", "B", 10)
            self.set_fill_color(240, 240, 240)
            self.cell(0, 8, self.doc_title, align="C", fill=True, new_x="LMARGIN", new_y="NEXT")
            self.ln(3)
    
    def footer(self):
        self.set_y(-15)
        self.set_font("NotoSansJP", "", 8)
        self.set_text_color(128)
        self.cell(0, 10, f"- {self.page_no()} -", align="C")
        self.set_text_color(0)
    
    def chapter_title(self, title):
        self.set_font("NotoSansJP", "B", 14)
        self.set_fill_color(0, 102, 153)
        self.set_text_color(255)
        self.cell(0, 10, f"  {title}", fill=True, new_x="LMARGIN", new_y="NEXT")
        self.set_text_color(0)
        self.ln(4)
    
    def section_title(self, title):
        self.set_font("NotoSansJP", "B", 11)
        self.set_fill_color(230, 242, 255)
        self.cell(0, 8, f" {title}", fill=True, new_x="LMARGIN", new_y="NEXT")
        self.ln(2)
    
    def body_text(self, text):
        self.set_font("NotoSansJP", "", 10)
        self.multi_cell(0, 6, text)
        self.ln(2)
    
    def add_table(self, headers, data, col_widths=None):
        """表を追加"""
        self.set_font("NotoSansJP", "", 9)
        
        if col_widths is None:
            col_widths = [190 / len(headers)] * len(headers)
        
        # ヘッダー行
        self.set_fill_color(0, 102, 153)
        self.set_text_color(255)
        self.set_font("NotoSansJP", "B", 9)
        for i, header in enumerate(headers):
            self.cell(col_widths[i], 8, header, border=1, fill=True, align="C")
        self.ln()
        
        # データ行
        self.set_text_color(0)
        self.set_font("NotoSansJP", "", 9)
        fill = False
        for row in data:
            self.set_fill_color(245, 250, 255) if fill else self.set_fill_color(255, 255, 255)
            for i, cell in enumerate(row):
                self.cell(col_widths[i], 7, str(cell), border=1, fill=True, align="C")
            self.ln()
            fill = not fill
        self.ln(3)
    
    def add_info_box(self, title, content, box_type="info"):
        """情報ボックスを追加（info, warning, success）"""
        colors = {
            "info": (230, 242, 255, 0, 102, 153),
            "warning": (255, 248, 220, 204, 153, 0),
            "success": (220, 255, 220, 0, 153, 51)
        }
        bg_r, bg_g, bg_b, border_r, border_g, border_b = colors.get(box_type, colors["info"])
        
        self.set_fill_color(bg_r, bg_g, bg_b)
        self.set_draw_color(border_r, border_g, border_b)
        
        # タイトル
        self.set_font("NotoSansJP", "B", 10)
        x, y = self.get_x(), self.get_y()
        self.rect(x, y, 190, 8, style="DF")
        self.cell(190, 8, f" {title}", new_x="LMARGIN", new_y="NEXT")
        
        # 内容
        self.set_font("NotoSansJP", "", 9)
        self.set_fill_color(255, 255, 255)
        lines = content.split('\n')
        h = len(lines) * 5 + 4
        x, y = self.get_x(), self.get_y()
        self.rect(x, y, 190, h, style="D")
        self.set_xy(x + 2, y + 2)
        self.multi_cell(186, 5, content)
        self.ln(3)
        self.set_draw_color(0)
    
    def add_flow_diagram(self, steps, title=""):
        """フロー図を追加"""
        if title:
            self.set_font("NotoSansJP", "B", 10)
            self.cell(0, 8, title, new_x="LMARGIN", new_y="NEXT")
        
        box_width = 50
        box_height = 12
        arrow_width = 15
        start_x = 20
        y = self.get_y() + 5
        
        self.set_font("NotoSansJP", "", 8)
        
        for i, step in enumerate(steps):
            x = start_x + i * (box_width + arrow_width)
            
            # 画面幅を超えたら改行
            if x + box_width > 190:
                y += box_height + 15
                start_x = 20
                x = start_x
            
            # ボックス描画
            self.set_fill_color(0, 102, 153)
            self.set_text_color(255)
            self.rect(x, y, box_width, box_height, style="F")
            self.set_xy(x, y + 3)
            self.cell(box_width, 6, step, align="C")
            
            # 矢印描画（最後以外）
            if i < len(steps) - 1:
                next_x = x + box_width + arrow_width
                if next_x + box_width <= 190:
                    self.set_draw_color(100)
                    self.set_line_width(0.5)
                    arrow_y = y + box_height / 2
                    self.line(x + box_width, arrow_y, x + box_width + arrow_width - 3, arrow_y)
                    # 矢印の先端
                    self.line(x + box_width + arrow_width - 6, arrow_y - 2, x + box_width + arrow_width - 3, arrow_y)
                    self.line(x + box_width + arrow_width - 6, arrow_y + 2, x + box_width + arrow_width - 3, arrow_y)
        
        self.set_text_color(0)
        self.set_draw_color(0)
        self.set_line_width(0.2)
        self.set_y(y + box_height + 10)


def create_deposit_regulations():
    """1. 預金規定.pdf を生成"""
    pdf = JapanesePDF()
    pdf.doc_title = "預金規定"
    pdf.add_page()
    
    pdf.chapter_title("普通預金規定")
    
    # 概要図
    pdf.add_info_box("普通預金の特徴", 
        "・いつでも自由に預入れ・払戻しが可能\n"
        "・給与振込、年金受取、各種引落しの指定口座として利用可能\n"
        "・キャッシュカードでATMから24時間利用可能",
        "info")
    
    pdf.section_title("第1条（預金の預入れ）")
    
    # 預入方法の表
    pdf.body_text("預入れ方法と限度額は以下のとおりです。")
    pdf.add_table(
        ["預入方法", "利用時間", "1回の限度額", "手数料"],
        [
            ["窓口", "平日9:00〜15:00", "制限なし", "無料"],
            ["ATM（現金）", "24時間", "200万円", "無料"],
            ["ATM（振込）", "24時間", "制限なし", "無料"],
            ["振込入金", "24時間", "制限なし", "無料"],
        ],
        [50, 50, 45, 45]
    )
    
    pdf.section_title("第2条（預金の払戻し）")
    
    # 払戻方法の表
    pdf.body_text("払戻し方法と限度額は以下のとおりです。")
    pdf.add_table(
        ["払戻方法", "必要なもの", "1日の限度額", "手数料"],
        [
            ["窓口", "通帳・届出印", "制限なし", "無料"],
            ["ATM", "キャッシュカード", "50万円※", "無料"],
            ["振込", "通帳・届出印", "制限なし", "振込手数料"],
        ],
        [45, 55, 45, 45]
    )
    pdf.body_text("※ATM限度額は窓口にて変更可能です（上限200万円）")
    
    pdf.section_title("第3条（預金利息）")
    
    # 利息計算の説明
    pdf.add_info_box("利息計算方法",
        "付利単位：100円\n"
        "計算期間：毎日の最終残高（1,000円以上）に対して日割計算\n"
        "利払日　：毎年2月・8月の所定日に元金に組入れ",
        "info")
    
    # 金利表
    pdf.body_text("現在の適用金利（2025年1月現在）")
    pdf.add_table(
        ["預金種類", "金利（年率）"],
        [
            ["普通預金", "0.020%"],
            ["貯蓄預金（基準残高以上）", "0.025%"],
        ],
        [95, 95]
    )
    
    pdf.section_title("第4条（届出事項の変更）")
    pdf.body_text("""氏名、住所、電話番号、印章その他届出事項に変更があった場合は、
直ちに書面により届出てください。届出がないために当行からの通知または
送付書類が延着し、または到着しなかった場合、通常届くべきときに届いたものとみなします。""")
    
    # 届出変更フロー
    pdf.add_flow_diagram(["届出内容確認", "届出書記入", "本人確認", "変更完了"], "届出変更の流れ")
    
    pdf.add_page()
    pdf.chapter_title("定期預金規定")
    
    pdf.section_title("第1条（預入れ）")
    
    # 定期預金の種類
    pdf.body_text("定期預金の種類と金利（2025年1月現在）")
    pdf.add_table(
        ["預入期間", "金利（年率）", "中途解約利率"],
        [
            ["1ヶ月", "0.125%", "普通預金金利"],
            ["3ヶ月", "0.125%", "普通預金金利"],
            ["6ヶ月", "0.150%", "普通預金金利"],
            ["1年", "0.275%", "普通預金金利"],
            ["2年", "0.350%", "普通預金金利"],
            ["3年", "0.400%", "普通預金金利"],
            ["5年", "0.500%", "普通預金金利"],
        ],
        [60, 65, 65]
    )
    
    pdf.section_title("第2条（満期時の取扱い）")
    pdf.add_table(
        ["取扱区分", "説明"],
        [
            ["自動継続（元利）", "元金と利息を合わせて同期間で継続"],
            ["自動継続（元金）", "元金のみ同期間で継続、利息は普通預金へ"],
            ["満期解約", "元金と利息を普通預金へ入金"],
        ],
        [60, 130]
    )
    
    output_path = os.path.join(OUTPUT_DIR, "預金規定.pdf")
    pdf.output(output_path)
    print(f"生成完了: {output_path}")


def create_compliance_manual():
    """2. 本人確認マニュアル.pdf を生成"""
    pdf = JapanesePDF()
    pdf.doc_title = "本人確認マニュアル"
    pdf.add_page()
    
    pdf.chapter_title("本人確認（犯罪収益移転防止法）マニュアル")
    
    # 概要
    pdf.add_info_box("本人確認の目的",
        "犯罪収益移転防止法に基づき、マネーロンダリングやテロ資金供与を防止するため、\n"
        "金融機関は一定の取引において顧客の本人確認を行う義務があります。",
        "warning")
    
    pdf.section_title("1. 本人確認が必要な取引")
    
    # 個人の取引一覧
    pdf.body_text("【個人のお客さま】")
    pdf.add_table(
        ["取引種類", "金額基準", "確認レベル"],
        [
            ["口座開設", "金額に関わらず", "通常"],
            ["大口現金取引", "200万円超", "通常"],
            ["現金振込", "10万円超", "通常"],
            ["融資取引", "金額に関わらず", "通常"],
            ["外国送金", "金額に関わらず", "厳格"],
        ],
        [70, 60, 60]
    )
    
    # 法人の取引一覧
    pdf.body_text("【法人のお客さま】")
    pdf.add_table(
        ["取引種類", "追加確認事項"],
        [
            ["口座開設", "実質的支配者の確認"],
            ["融資取引", "実質的支配者の確認"],
            ["外国送金", "取引目的・送金先の確認"],
        ],
        [70, 120]
    )
    
    pdf.section_title("2. 本人確認書類（個人）")
    
    pdf.add_table(
        ["種別", "書類名", "有効期限確認"],
        [
            ["写真付（1点でOK）", "運転免許証", "要"],
            ["写真付（1点でOK）", "マイナンバーカード", "要"],
            ["写真付（1点でOK）", "パスポート", "要"],
            ["写真付（1点でOK）", "在留カード", "要"],
            ["写真なし（2点必要）", "健康保険証", "要"],
            ["写真なし（2点必要）", "年金手帳", "－"],
            ["補完書類", "住民票（3ヶ月以内）", "発行日確認"],
            ["補完書類", "公共料金領収書（3ヶ月以内）", "発行日確認"],
        ],
        [55, 80, 55]
    )
    
    pdf.add_page()
    pdf.section_title("3. 本人確認書類（法人）")
    
    pdf.add_table(
        ["確認対象", "必要書類"],
        [
            ["法人の実在", "登記事項証明書（3ヶ月以内）"],
            ["法人の実在", "印鑑登録証明書（3ヶ月以内）"],
            ["取引担当者", "個人の本人確認書類＋委任状"],
            ["実質的支配者", "申告書（当行所定）"],
        ],
        [60, 130]
    )
    
    # 実質的支配者の判定フロー
    pdf.section_title("4. 実質的支配者の判定")
    
    pdf.add_info_box("実質的支配者とは",
        "法人の事業活動に支配的な影響力を有する自然人のこと。\n"
        "以下の順序で判定します。",
        "info")
    
    pdf.add_table(
        ["優先順位", "判定基準", "確認書類"],
        [
            ["1", "議決権25%超を保有する自然人", "株主名簿等"],
            ["2", "事業活動に支配的影響力を有する自然人", "組織図等"],
            ["3", "上記該当者なしの場合、代表者", "登記事項証明書"],
        ],
        [30, 100, 60]
    )
    
    pdf.section_title("5. 確認記録の作成・保存")
    
    pdf.add_flow_diagram(["本人確認実施", "記録作成", "システム入力", "原本保管", "7年間保存"], "確認記録のフロー")
    
    pdf.add_table(
        ["記録項目", "記録内容"],
        [
            ["確認日時", "本人確認を行った日付・時刻"],
            ["確認者", "確認を行った担当者名"],
            ["確認書類", "書類名・記号番号"],
            ["顧客情報", "氏名・住所・生年月日"],
            ["取引内容", "取引の種類・金額"],
        ],
        [50, 140]
    )
    
    pdf.section_title("6. 疑わしい取引の届出")
    
    pdf.add_info_box("疑わしい取引の例",
        "・合理的な理由のない多額の現金取引\n"
        "・短期間での頻繁な取引（経済合理性なし）\n"
        "・架空名義・借名が疑われる取引\n"
        "・口座開設直後の多額入出金",
        "warning")
    
    pdf.add_flow_diagram(["疑義発見", "シート記入", "上席者報告", "コンプラ部門", "金融庁届出"], "届出フロー")
    
    output_path = os.path.join(OUTPUT_DIR, "本人確認マニュアル.pdf")
    pdf.output(output_path)
    print(f"生成完了: {output_path}")


def create_housing_loan_guide():
    """3. 住宅ローン商品説明書.pdf を生成"""
    pdf = JapanesePDF()
    pdf.doc_title = "住宅ローン商品説明書"
    pdf.add_page()
    
    pdf.chapter_title("住宅ローン「夢プラン」商品概要")
    
    # 商品ハイライト
    pdf.add_info_box("商品の特徴",
        "✓ 最大1億円までご融資可能\n"
        "✓ 最長35年の長期返済\n"
        "✓ 変動・固定選択・全期間固定から選べる金利タイプ\n"
        "✓ 一部繰上返済手数料無料（インターネットバンキング）",
        "success")
    
    pdf.section_title("1. ご利用条件")
    
    pdf.add_table(
        ["項目", "条件"],
        [
            ["年齢", "申込時20歳以上65歳以下、完済時80歳以下"],
            ["収入", "安定した収入のある方"],
            ["勤続年数", "給与所得者1年以上、自営業者2年以上"],
            ["保証", "当行指定保証会社の保証を受けられる方"],
            ["団信", "団体信用生命保険に加入できる方"],
        ],
        [50, 140]
    )
    
    pdf.section_title("2. 融資条件")
    
    pdf.add_table(
        ["項目", "内容"],
        [
            ["融資金額", "100万円〜1億円（10万円単位）"],
            ["融資期間", "1年〜35年（1年単位）"],
            ["返済方法", "元利均等返済 or 元金均等返済"],
            ["ボーナス返済", "併用可（融資額の50%以内）"],
        ],
        [50, 140]
    )
    
    pdf.section_title("3. 返済比率の目安")
    
    pdf.add_table(
        ["年収", "返済比率上限", "借入可能額の目安（35年・金利1%）"],
        [
            ["300万円", "30%", "約2,400万円"],
            ["400万円", "35%", "約3,700万円"],
            ["500万円", "35%", "約4,600万円"],
            ["600万円", "35%", "約5,500万円"],
            ["800万円", "35%", "約7,400万円"],
        ],
        [50, 50, 90]
    )
    
    pdf.add_page()
    pdf.section_title("4. 金利タイプ比較")
    
    pdf.add_table(
        ["金利タイプ", "特徴", "適用金利（2025年1月）"],
        [
            ["変動金利", "半年ごとに見直し、低金利時に有利", "年0.475%〜"],
            ["固定2年", "2年間金利固定", "年0.95%〜"],
            ["固定5年", "5年間金利固定", "年1.10%〜"],
            ["固定10年", "10年間金利固定", "年1.35%〜"],
            ["全期間固定", "完済まで金利一定", "年1.50%〜"],
        ],
        [45, 90, 55]
    )
    
    # 金利タイプ選択の目安
    pdf.add_info_box("金利タイプ選択のポイント",
        "【変動金利向き】短期返済予定、金利上昇リスク許容可、低金利重視\n"
        "【固定金利向き】長期返済予定、返済額安定重視、金利上昇リスク回避",
        "info")
    
    pdf.section_title("5. 諸費用")
    
    pdf.add_table(
        ["費用項目", "金額", "支払時期"],
        [
            ["事務取扱手数料", "55,000円（税込）", "融資実行時"],
            ["保証料（一括）", "約20,000円/100万円・35年", "融資実行時"],
            ["保証料（上乗せ）", "金利+0.2%", "毎月返済時"],
            ["抵当権設定費用", "借入額の0.4%程度", "融資実行時"],
            ["火災保険料", "建物により異なる", "融資実行時"],
        ],
        [60, 75, 55]
    )
    
    pdf.section_title("6. 繰上返済手数料")
    
    pdf.add_table(
        ["返済方法", "一部繰上返済", "全額繰上返済"],
        [
            ["インターネット", "無料", "22,000円"],
            ["窓口", "5,500円", "22,000円"],
        ],
        [70, 60, 60]
    )
    
    pdf.section_title("7. お申込みの流れ")
    
    pdf.add_flow_diagram(["事前審査", "本審査", "契約", "融資実行", "返済開始"], "")
    
    pdf.add_table(
        ["ステップ", "所要期間", "必要書類"],
        [
            ["事前審査", "3〜5営業日", "本人確認書類、収入証明"],
            ["本審査", "1〜2週間", "物件資料、印鑑証明等"],
            ["契約", "1日", "実印、契約書類"],
            ["融資実行", "決済日", "－"],
        ],
        [50, 50, 90]
    )
    
    output_path = os.path.join(OUTPUT_DIR, "住宅ローン商品説明書.pdf")
    pdf.output(output_path)
    print(f"生成完了: {output_path}")


def create_card_loan_guide():
    """4. カードローン商品説明書.pdf を生成"""
    pdf = JapanesePDF()
    pdf.doc_title = "カードローン商品説明書"
    pdf.add_page()
    
    pdf.chapter_title("カードローン「スマートサポート」商品概要")
    
    # 商品ハイライト
    pdf.add_info_box("商品の特徴",
        "✓ 来店不要！スマホで簡単お申込み\n"
        "✓ 最短即日審査回答\n"
        "✓ ATM手数料無料（当行ATM）\n"
        "✓ 担保・保証人不要",
        "success")
    
    pdf.section_title("1. ご利用条件")
    
    pdf.add_table(
        ["項目", "条件"],
        [
            ["年齢", "満20歳以上65歳以下"],
            ["収入", "安定継続した収入のある方"],
            ["雇用形態", "正社員・契約社員・パート・アルバイト可"],
            ["居住地", "当行営業区域内"],
        ],
        [50, 140]
    )
    
    pdf.section_title("2. 限度額と金利")
    
    pdf.add_table(
        ["ご利用限度額", "適用金利（年率）"],
        [
            ["10万円〜50万円", "14.5%"],
            ["60万円〜100万円", "12.0%"],
            ["110万円〜200万円", "9.0%"],
            ["210万円〜300万円", "7.0%"],
            ["310万円〜400万円", "5.0%"],
            ["410万円〜500万円", "3.5%"],
        ],
        [95, 95]
    )
    
    pdf.add_info_box("金利の計算例",
        "限度額100万円、金利12.0%、10万円を30日間借入れた場合\n"
        "利息 = 100,000円 × 12.0% × 30日 ÷ 365日 = 986円",
        "info")
    
    pdf.section_title("3. 毎月のご返済額")
    
    pdf.add_table(
        ["前月10日時点の借入残高", "約定返済額"],
        [
            ["10万円以下", "2,000円"],
            ["10万円超〜50万円", "10,000円"],
            ["50万円超〜100万円", "20,000円"],
            ["100万円超〜200万円", "30,000円"],
            ["200万円超〜300万円", "40,000円"],
            ["300万円超", "50,000円"],
        ],
        [95, 95]
    )
    
    pdf.add_page()
    pdf.section_title("4. お借入れ・ご返済方法")
    
    # 借入方法
    pdf.body_text("【お借入れ方法】")
    pdf.add_table(
        ["方法", "利用時間", "手数料", "1回の限度額"],
        [
            ["当行ATM", "24時間", "無料", "50万円"],
            ["コンビニATM", "24時間", "110〜220円", "50万円"],
            ["インターネット", "24時間", "無料", "限度額まで"],
        ],
        [55, 45, 45, 45]
    )
    
    # 返済方法
    pdf.body_text("【ご返済方法】")
    pdf.add_table(
        ["方法", "返済日", "手数料"],
        [
            ["自動引落（約定返済）", "毎月10日", "無料"],
            ["ATM随時返済", "いつでも", "無料"],
            ["振込返済", "いつでも", "振込手数料"],
        ],
        [65, 65, 60]
    )
    
    pdf.section_title("5. お申込みの流れ")
    
    pdf.add_flow_diagram(["Web申込", "審査", "契約", "カード届く", "利用開始"], "")
    
    pdf.add_table(
        ["ステップ", "所要時間", "備考"],
        [
            ["Web申込", "5分", "24時間受付"],
            ["審査回答", "最短即日", "平日15時までの申込"],
            ["契約手続", "Web完結", "来店不要"],
            ["カード到着", "約1週間", "簡易書留"],
        ],
        [50, 50, 90]
    )
    
    pdf.section_title("6. 必要書類")
    
    pdf.add_table(
        ["限度額", "本人確認書類", "収入証明書類"],
        [
            ["50万円以下", "運転免許証等 1点", "不要"],
            ["50万円超", "運転免許証等 1点", "源泉徴収票等"],
        ],
        [55, 70, 65]
    )
    
    pdf.section_title("7. ご注意事項")
    
    pdf.add_info_box("ご返済に関する注意",
        "・計画的なご利用をお願いします\n"
        "・返済日に残高不足の場合、遅延損害金（年14.5%）が発生します\n"
        "・お困りの際は早めにご相談ください\n"
        "・相談窓口：カードローンセンター 0120-XXX-XXX（平日9:00〜17:00）",
        "warning")
    
    output_path = os.path.join(OUTPUT_DIR, "カードローン商品説明書.pdf")
    pdf.output(output_path)
    print(f"生成完了: {output_path}")


def main():
    """すべてのPDFを生成"""
    print("=" * 50)
    print("サンプルPDFドキュメント生成開始（図表入り版）")
    print("=" * 50)
    
    create_deposit_regulations()
    create_compliance_manual()
    create_housing_loan_guide()
    create_card_loan_guide()
    
    print("=" * 50)
    print("すべてのPDF生成が完了しました")
    print(f"出力先: {OUTPUT_DIR}")
    print("=" * 50)


if __name__ == "__main__":
    main()
