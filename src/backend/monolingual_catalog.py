"""
Monolingual Vietnamese & English Catalog and Translator for NutriViet FoodOn Engine
===================================================================================
Guarantees strictly monolingual output:
  - When `lang == 'vi'`: 100% pure Vietnamese titles, descriptions, synonyms, and lineage labels (zero English words).
  - When `lang == 'en'`: 100% pure English titles, descriptions, synonyms, and lineage labels (zero Vietnamese words).
"""

import re

ALLERGEN_DISPLAY_NAMES_VI = {
    "peanuts": "Đậu phộng (Lạc)",
    "seafood": "Hải sản, giáp xác và cá",
    "milk": "Sữa bò và chế phẩm từ sữa",
    "gluten": "Ngũ cốc chứa đạm lúa mì, đại mạch, yến mạch",
    "eggs": "Trứng và chế phẩm từ trứng",
    "soy": "Đậu nành (Đỗ tương)",
    "tree_nuts": "Các loại hạt cây (Hạnh nhân, óc chó, hạt điều, hạt phỉ)",
    "sesame": "Hạt mè (Vừng)",
    "curie:FOODON:00001006": "Thịt động vật có vú (Thịt đỏ: Bò, Heo, Cừu)",
    "curie:FOODON:00001134": "Thịt bò và chế phẩm từ bò",
    "curie:FOODON:00001038": "Thịt heo (Thịt lợn) và chế phẩm",
    "curie:FOODON:00001131": "Thịt gia cầm (Gà, Vịt, Ngan, Ngỗng)",
    "curie:FOODON:00001040": "Thịt gà và chế phẩm từ gà",
    "curie:FOODON:00001092": "Thịt và sản phẩm động vật có xương sống",
}

ALLERGEN_DISPLAY_NAMES_EN = {
    "peanuts": "Peanuts",
    "seafood": "Seafood, Crustaceans & Fish",
    "milk": "Cow's Milk & Dairy Products",
    "gluten": "Gluten-Containing Cereals (Wheat, Barley, Oats)",
    "eggs": "Eggs & Egg Products",
    "soy": "Soybeans",
    "tree_nuts": "Tree Nuts (Almond, Walnut, Cashew, Hazelnut)",
    "sesame": "Sesame Seeds",
    "curie:FOODON:00001006": "Mammalian Meat (Red Meat: Beef, Pork, Lamb)",
    "curie:FOODON:00001134": "Beef & Bovine Meat Products",
    "curie:FOODON:00001038": "Pork & Swine Meat Products",
    "curie:FOODON:00001131": "Poultry Meat (Chicken, Duck, Turkey)",
    "curie:FOODON:00001040": "Chicken Meat & Poultry Derivatives",
    "curie:FOODON:00001092": "Vertebrate Animal Meat Products",
}

CHRONIC_DISPLAY_NAMES_VI = {
    "gout": "Bệnh gút và axit uric cao",
    "diabetes": "Bệnh tiểu đường (Cần kiểm soát đường)",
    "hypertension": "Bệnh tăng huyết áp (Cần kiểm soát muối và natri)",
    "cholesterol": "Mỡ máu và cholesterol cao",
}

CHRONIC_DISPLAY_NAMES_EN = {
    "gout": "Gout & High Uric Acid",
    "diabetes": "Diabetes (Sugar & Carbohydrate Control)",
    "hypertension": "Hypertension (Salt & Sodium Control)",
    "cholesterol": "High Cholesterol & Dyslipidemia",
}

# Canonical FoodOn / CHEBI CURIEs for the 4 Home Screen categories
CURATED_CATEGORY_CURIES = {
    "sugar": [
        "CHEBI:17992",      # Sucrose / Đường mía tinh luyện
        "CHEBI:17234",      # Glucose / Đường nho
        "CHEBI:28757",      # Fructose / Đường trái cây
        "CHEBI:17306",      # Maltose / Đường mạch nha
        "CHEBI:17716",      # Lactose / Đường sữa
        "CHEBI:28260",      # Galactose / Đường đơn galactose
        "FOODON:00005790",  # Glucose syrup / Siro đường nho
        "FOODON:03301061",  # Corn syrup / Siro ngô
        "FOODON:03301847",  # Cane syrup / Siro mía
        "FOODON:00005587",  # Malt syrup / Siro mạch nha
        "FOODON:00001178",  # Honey food product / Mật ong tự nhiên
        "CHEBI:83163",      # Molasses / Mật rỉ đường mía
        "FOODON:00001083",  # Sugar condiment / Gia vị đường ăn
        "FOODON:00002300",  # Sweetener / Chất tạo ngọt thực phẩm
        "CHEBI:30911",      # Sorbitol (E420)
        "CHEBI:32111",      # Saccharin (E954)
        "CHEBI:2877",       # Aspartame (E951)
        "CHEBI:32159",      # Sucralose (E955)
        "CHEBI:83501",      # Acesulfame K (E950)
        "FOODON:03414456",  # Steviol glycosides (E960)
    ],
    "salt": [
        "CHEBI:26710",      # Sodium chloride / Muối ăn tinh luyện
        "CHEBI:64220",      # Monosodium glutamate (E621) / Bột ngọt (Mì chính)
        "CHEBI:113455",     # Sodium benzoate (E211)
        "CHEBI:78870",      # Sodium nitrite (E250)
        "CHEBI:63005",      # Sodium nitrate (E251)
        "CHEBI:53258",      # Sodium citrate (E331)
        "CHEBI:34683",      # Disodium phosphate (E339)
        "CHEBI:113451",     # Sodium ascorbate (E301)
        "CHEBI:132106",     # Sodium propionate (E281)
        "CHEBI:32954",      # Sodium acetate (E262)
        "CHEBI:75228",      # Sodium lactate (E325)
        "CHEBI:86477",      # Sodium sulfite (E221)
        "CHEBI:114786",     # Sodium metabisulfite (E223)
        "FOODON:03413087",  # Disodium guanylate (E627)
        "FOODON:03413088",  # Disodium inosinate (E631)
        "FOODON:03413084",  # Disodium 5'-ribonucleotides (E635)
        "CHEBI:29377",      # Sodium carbonate (E500)
        "CHEBI:32588",      # Potassium chloride (E508)
        "CHEBI:24866",      # Salt / Muối khoáng thực phẩm
    ],
    "fat": [
        "CHEBI:16113",      # Cholesterol / Mỡ máu cholesterol
        "CHEBI:26607",      # Saturated fatty acid / Axit béo bão hòa
        "FOODON:02010033",  # Animal fat / Mỡ động vật
        "FOODON:03302051",  # Lard / Mỡ heo (Mỡ lợn)
        "FOODON:00005450",  # Pork fat / Mỡ thịt heo
        "FOODON:03310232",  # Palm oil / Dầu cọ thực vật
        "FOODON:00003211",  # Hydrogenated palm kernel oil / Dầu nhân cọ hyđrô hóa
        "FOODON:00003213",  # Hydrogenated coconut oil / Dầu dừa hyđrô hóa
        "FOODON:00002078",  # Refined palm oil / Dầu cọ tinh luyện
        "FOODON:00001023",  # Dairy butter / Bơ sữa động vật
        "FOODON:00002681",  # Milk fat / Chất béo từ sữa
        "CHEBI:15756",      # Palmitic acid / Axit béo palmitic
        "CHEBI:28842",      # Stearic acid / Axit béo stearic
        "CHEBI:28875",      # Myristic acid / Axit béo myristic
        "CHEBI:30805",      # Lauric acid / Axit béo lauric
        "FOODON:03413156",  # Mono- and diglycerides of fatty acids (E471)
        "CHEBI:35366",      # Fatty acid (E570)
    ],
    "allergen": {
        "peanuts": ["FOODON:00003206", "FOODON:00002099", "FOODON:00003207"],
        "soy": ["FOODON:00002266", "CHEBI:61995", "FOODON:00002783"],
        "milk": ["FOODON:00001257", "CHEBI:17716", "FOODON:03420180", "FOODON:00002174", "FOODON:03315518"],
        "eggs": ["FOODON:00001274", "FOODON:00004428", "FOODON:03413135"],
        "seafood": ["FOODON:00002239", "FOODON:00001248", "FOODON:00002679"],
        "gluten": ["FOODON:03420177", "FOODON:03310809", "FOODON:00001210", "FOODON:00001141"],
        "tree_nuts": ["FOODON:00003523", "FOODON:03301364", "FOODON:00003615", "FOODON:00002933", "FOODON:00003691", "FOODON:00003003"],
        "sesame": ["FOODON:00002232", "FOODON:00004578", "FOODON:00004525"],
    },
}

# Noisy Kala general-dictionary homonyms that must be excluded in food contexts
BAD_KALA_VI_TERMS = {
    "quỷ", "em yêu", "xà phòng", "dền", "xem gum arabic", "bầu giời trong sáng",
    "nham", "phân lân", "mặn", "chất bổ", "đồng cỏ", "làm vội", "biển", "viên",
    "nõ", "người hay gây sự", "bánh", "viết tắt là p", "con đội", "cây thương",
    "đường ho hená học", "quét sen lắc", "khí gây tê", "nhũ toan", "a dốt",
    "dở hơi", "mê say", "lẩn thẩn", "sức mạnh", "thể lực", "tiền của", "chức vị",
    "các nhà (chính trị", "kẻ ngu ngốc", "xe lội nước", "phở", "sự cắt", "vết đứt",
    "điệu nhảy", "công việc dễ ăn", "người béo phì", "vỏ bào", "dây bện",
    "người bẩn thỉu", "xa lô", "thợ cạo", "cái nêm", "súc sắc", "nghiêm lệnh",
    "gậy chơi bi a", "chớ nàyp", "ném dẹm", "hơ hayng", "nói về thịt bò",
}

# Curated Vietnamese titles & descriptions by E-code (100% pure Vietnamese)
ECODE_VI_CATALOG = {
    "E100": ("Tinh chất màu nghệ tự nhiên", "Chất tạo màu vàng tự nhiên chiết xuất từ thân rễ cây nghệ, an toàn khi dùng ở liều lượng thực phẩm."),
    "E101": ("Vitamin B2 tạo màu vàng cam", "Dưỡng chất nhóm vitamin B thiết yếu có tự nhiên trong rau xanh, nấm và sữa, dùng làm chất tạo màu vàng thực phẩm."),
    "E102": ("Phẩm màu vàng chanh tổng hợp", "Phẩm màu thực phẩm tổng hợp tạo sắc vàng tươi, cần thận trọng với người có cơ địa mẫn cảm hoặc dị ứng."),
    "E104": ("Phẩm màu vàng lục tổng hợp", "Phẩm màu thực phẩm tổng hợp dùng trong nước giải khát và bánh kẹo, khuyến nghị hạn chế dùng nhiều cho trẻ nhỏ."),
    "E110": ("Phẩm màu vàng cam tổng hợp", "Phẩm màu thực phẩm tổng hợp tạo sắc cam đậm trong đồ uống và mứt kẹo, cần lưu ý với người nhạy cảm phụ gia."),
    "E120": ("Phẩm màu đỏ son tự nhiên", "Sắc tố màu đỏ tự nhiên chiết xuất truyền thống dùng trong sữa chua, kẹo và chế phẩm thịt."),
    "E122": ("Phẩm màu đỏ dâu tổng hợp", "Phẩm màu thực phẩm tổng hợp tạo sắc đỏ thẫm cho bánh kẹo, thạch và nước giải khát."),
    "E123": ("Phẩm màu đỏ tía tổng hợp", "Phẩm màu tổng hợp tạo sắc đỏ tím đậm, nằm trong nhóm phụ gia màu cần kiểm soát chặt liều lượng."),
    "E124": ("Phẩm màu đỏ tươi tổng hợp", "Phẩm màu tổng hợp tạo sắc đỏ anh đào trong bánh ngọt, xúc xích và đồ uống có hương trái cây."),
    "E127": ("Phẩm màu đỏ hồng tổng hợp", "Phẩm màu thực phẩm tổng hợp chứa i-ốt tạo sắc hồng sáng cho kẹo và trái cây đóng hộp."),
    "E128": ("Phẩm màu đỏ thực phẩm tổng hợp nhóm 2G", "Phẩm màu tổng hợp tạo sắc đỏ bền nhiệt, thuộc nhóm phụ gia màu hạn chế sử dụng."),
    "E129": ("Phẩm màu đỏ cam tổng hợp", "Phẩm màu thực phẩm tổng hợp phổ biến trong nước ngọt, bánh quy và ngũ cốc ăn sáng."),
    "E131": ("Phẩm màu xanh dương sáng tổng hợp", "Phẩm màu tổng hợp tạo sắc xanh lam tươi trong kẹo ngậm và đồ uống giải khát."),
    "E132": ("Phẩm màu xanh chàm tổng hợp", "Phẩm màu thực phẩm tổng hợp tạo sắc xanh tím chàm cho kem, bánh kẹo và viên bọc đường."),
    "E133": ("Phẩm màu xanh lam rực tổng hợp", "Phẩm màu tổng hợp tạo sắc xanh dương trong trẻo, thường phối hợp để tạo màu xanh lá trong thực phẩm."),
    "E140": ("Chất màu xanh diệp lục tự nhiên", "Sắc tố xanh lá cây tự nhiên chiết xuất từ thực vật và rau xanh, dùng tạo màu tự nhiên cho thực phẩm."),
    "E141": ("Phức chất đồng của màu diệp lục", "Chất tạo màu xanh lá bền nhiệt có nguồn gốc từ sắc tố diệp lục thực vật."),
    "E142": ("Phẩm màu xanh lục tổng hợp", "Phẩm màu tổng hợp tạo sắc xanh lá cho đậu Hà Lan đóng hộp, sốt bạc hà và bánh kẹo."),
    "E150": ("Màu đường thắng tự nhiên", "Chất tạo màu nâu truyền thống thu được bằng cách gia nhiệt đường ăn tự nhiên."),
    "E150A": ("Màu đường thắng nguyên chất nhóm một", "Màu nâu tự nhiên chế biến từ đường tinh luyện đun nóng không dùng hóa chất xúc tác."),
    "E150B": ("Màu đường thắng xử lý sunfit nhóm hai", "Phụ gia tạo màu nâu caramen có sử dụng hợp chất sunfit trong quá trình gia nhiệt đường."),
    "E150C": ("Màu đường thắng xử lý amoni nhóm ba", "Phụ gia tạo màu nâu caramen dùng trong nước tương, sốt gia vị và đồ uống lên men."),
    "E150D": ("Màu đường thắng xử lý sunfit amoni nhóm bốn", "Phụ gia tạo màu nâu sẫm phổ biến trong nước giải khát có ga và sốt ướp thực phẩm."),
    "E151": ("Phẩm màu đen bóng tổng hợp", "Phẩm màu thực phẩm tổng hợp tạo sắc đen tím cho kẹo cam thảo và sốt trang trí."),
    "E153": ("Than thực vật tạo màu đen tự nhiên", "Chất màu đen tự nhiên thu từ quá trình than hóa nguyên liệu thực vật tinh khiết."),
    "E154": ("Phẩm màu nâu thực phẩm tổng hợp nhóm một", "Phẩm màu tổng hợp tạo sắc nâu khói dùng cho một số sản phẩm cá hun khói."),
    "E155": ("Phẩm màu nâu sô-cô-la tổng hợp", "Phẩm màu tổng hợp bền nhiệt dùng tạo màu nâu cho bánh nướng và sản phẩm hương ca cao."),
    "E160A": ("Tiền chất vitamin A tạo màu vàng cam", "Sắc tố vàng cam tự nhiên có nhiều trong cà rốt, bí đỏ và gấc, đồng thời là nguồn cung cấp tiền chất vitamin A."),
    "E160B": ("Chất màu hạt điều màu tự nhiên", "Sắc tố đỏ cam tự nhiên chiết xuất từ lớp vỏ hạt điều màu, thường dùng trong phô mai, bơ và món nấu."),
    "E160C": ("Tinh chất màu ớt đỏ tự nhiên", "Chất tạo màu cam đỏ và hương vị nhẹ chiết xuất tự nhiên từ quả ớt chín."),
    "E160D": ("Sắc tố đỏ cà chua tự nhiên", "Hoạt chất chống oxy hóa và tạo màu đỏ tự nhiên chiết xuất từ quả cà chua chín."),
    "E160E": ("Sắc tố vàng cam nhóm carotenoit", "Chất tạo màu cam đỏ thuộc nhóm sắc tố carotenoit dùng trong phô mai và kem tráng miệng."),
    "E160F": ("Este sắc tố vàng cam nhóm carotenoit", "Dẫn xuất este của sắc tố carotenoit dùng tạo màu vàng cam ổn định trong thực phẩm."),
    "E161B": ("Sắc tố vàng hoa cúc tự nhiên", "Sắc tố vàng tự nhiên thuộc nhóm dưỡng chất tốt cho thị lực, có nhiều trong lòng đỏ trứng và rau lá xanh."),
    "E161G": ("Sắc tố cam hồng nhóm carotenoit", "Sắc tố tự nhiên có trong nấm và giáp xác, dùng tạo màu cam hồng cho thực phẩm."),
    "E162": ("Chất màu đỏ củ dền tự nhiên", "Sắc tố đỏ tím tự nhiên chiết xuất từ củ dền đỏ, an toàn và dùng phổ biến trong kem, sữa chua."),
    "E163": ("Sắc tố tím thực vật tự nhiên", "Nhóm sắc tố chống oxy hóa tự nhiên chiết xuất từ vỏ nho, dâu tằm và bắp cải tím."),
    "E170": ("Muối khoáng canxi cacbonat", "Khoáng chất canxi tự nhiên dùng làm chất tạo màu trắng bề mặt, chất chống đông vón và bổ sung canxi."),
    "E171": ("Chất tạo màu trắng điôxít titan", "Khoáng chất tạo độ trắng đục và bóng cho lớp vỏ kẹo, hiện được khuyến nghị hạn chế sử dụng trong thực phẩm."),
    "E172": ("Chất màu khoáng ôxít và hyđrôxít sắt", "Nhóm khoáng chất sắt tạo sắc vàng, đỏ hoặc đen tự nhiên cho vỏ viên thực phẩm và bánh kẹo."),
    "E173": ("Chất tạo ánh bạc kim loại nhôm", "Lớp phủ trang trí ánh bạc dùng giới hạn trên bề mặt kẹo và bánh kem trang trí."),
    "E174": ("Chất phủ trang trí ánh bạc", "Kim loại bạc tinh khiết dùng cực nhỏ để trang trí bề mặt bánh kẹo cao cấp."),
    "E175": ("Chất phủ trang trí ánh vàng", "Lá vàng thực phẩm dùng trang trí bề mặt bánh ngọt và đồ uống đặc sản."),
    "E180": ("Phẩm màu đỏ vỏ phô mai", "Phẩm màu tổng hợp chỉ dùng cho lớp vỏ bọc bên ngoài của một số loại phô mai cứng."),
    "E200": ("Axit sorbic bảo quản chống nấm mốc", "Axit hữu cơ bảo quản thực phẩm giúp ức chế nấm men và nấm mốc trong bánh ngọt, phô mai."),
    "E202": ("Muối kali sorbat bảo quản thực phẩm", "Muối kali của axit sorbic dễ hòa tan, dùng phổ biến để chống mốc trong giò chả, bánh mì và nước sốt."),
    "E203": ("Muối canxi sorbat bảo quản thực phẩm", "Muối canxi bảo quản giúp ngăn ngừa nấm mốc phát triển trên bề mặt phô mai và chất béo."),
    "E210": ("Axit benzoic bảo quản thực phẩm", "Chất bảo quản kháng khuẩn và kháng nấm dùng trong nước giải khát có ga, tương ớt và dưa muối."),
    "E211": ("Muối natri benzoat bảo quản thực phẩm", "Chất bảo quản phổ biến trong nước ngọt, nước chấm và thực phẩm chua; chứa natri nên người tăng huyết áp cần lưu ý."),
    "E212": ("Muối kali benzoat bảo quản thực phẩm", "Chất bảo quản thay thế muối natri benzoat trong các sản phẩm đồ uống giảm muối."),
    "E213": ("Muối canxi benzoat bảo quản thực phẩm", "Chất bảo quản chống vi sinh vật dùng trong đồ uống và thực phẩm đóng gói."),
    "E214": ("Chất bảo quản este etyl paraben", "Phụ gia bảo quản kháng nấm thuộc nhóm este, cần hạn chế dùng thường xuyên."),
    "E215": ("Muối natri của etyl paraben", "Dẫn xuất muối natri bảo quản kháng nấm mốc trong thực phẩm chế biến."),
    "E216": ("Chất bảo quản este propyl paraben", "Phụ gia bảo quản tổng hợp thuộc nhóm paraben có nguy cơ gây kích ứng ở người nhạy cảm."),
    "E217": ("Muối natri của propyl paraben", "Dẫn xuất muối natri bảo quản tổng hợp thuộc nhóm cần hạn chế sử dụng."),
    "E218": ("Chất bảo quản este metyl paraben", "Phụ gia bảo quản chống nấm mốc tổng hợp, cần thận trọng với người có cơ địa dị ứng."),
    "E219": ("Muối natri của metyl paraben", "Muối natri hòa tan của chất bảo quản metyl paraben."),
    "E220": ("Khí lưu huỳnh điôxít bảo quản và chống thâm", "Chất bảo quản và chống oxy hóa giữ màu cho trái cây sấy khô; có thể gây kích ứng đường hô hấp ở người hen suyễn."),
    "E221": ("Muối natri sunfit bảo quản", "Muối sunfit chống oxy hóa và giữ màu thực phẩm, cần lưu ý với người nhạy cảm sunfit và tăng huyết áp."),
    "E222": ("Muối natri hyđrô sunfit", "Phụ gia bảo quản và chống hóa nâu thuộc nhóm muối sunfit."),
    "E223": ("Muối natri đisunfit bảo quản", "Chất bảo quản và tẩy trắng thực phẩm nhóm sunfit dùng trong mứt quả và hải sản đông lạnh."),
    "E224": ("Muối kali metabisunfit bảo quản", "Chất chống oxy hóa và ức chế vi sinh vật trong rượu vang, nước ép trái cây và trái cây sấy."),
    "E226": ("Muối canxi sunfit bảo quản", "Phụ gia bảo quản và giữ độ săn chắc cho rau củ quả chế biến."),
    "E227": ("Muối canxi hyđrô sunfit", "Phụ gia bảo quản chống nấm men và vi khuẩn nhóm sunfit."),
    "E228": ("Muối kali hyđrô sunfit", "Phụ gia bảo quản chống oxy hóa trong đồ uống lên men và trái cây sấy."),
    "E230": ("Hợp chất bảo quản vỏ trái cây có múi", "Chất chống nấm mốc xử lý bề mặt vỏ cam, chanh nhập khẩu bảo quản dài ngày."),
    "E231": ("Chất chống nấm mốc bề mặt vỏ quả", "Hợp chất kháng nấm dùng xử lý ngoài vỏ trái cây có múi sau thu hoạch."),
    "E232": ("Muối natri chống nấm bề mặt vỏ quả", "Dạng muối hòa tan dùng bảo quản chống mốc vỏ trái cây sau thu hoạch."),
    "E233": ("Hoạt chất kháng nấm bảo quản nông sản", "Chất chống nấm bề mặt nông sản, không dùng trực tiếp vào phần thịt quả ăn được."),
    "E234": ("Hoạt chất kháng khuẩn tự nhiên từ lên men sữa", "Peptit kháng khuẩn tự nhiên sinh ra từ vi khuẩn lên men sữa, giúp bảo quản phô mai và thực phẩm an toàn."),
    "E235": ("Chất kháng nấm tự nhiên bề mặt phô mai", "Hợp chất chống nấm mốc tự nhiên dùng bảo vệ lớp vỏ ngoài của phô mai và xúc xích khô."),
    "E239": ("Phụ gia bảo quản chống vi khuẩn sinh hơi", "Chất bảo quản chuyên dụng trong một số loại phô mai ủ chín truyền thống."),
    "E242": ("Chất khử trùng đồ uống đóng chai", "Phụ gia bảo quản tự phân hủy nhanh sau khi đóng chai nước trái cây và trà giải khát."),
    "E249": ("Muối kali nitrit giữ màu và bảo quản thịt", "Phụ gia ức chế vi khuẩn độc thịt và giữ màu hồng cho thịt nguội, không nên ăn lượng lớn thường xuyên."),
    "E250": ("Muối natri nitrit giữ màu và bảo quản thịt", "Phụ gia bảo quản trong xúc xích, thịt xông khói và lạp xưởng; cần hạn chế tiêu thụ nhiều để bảo vệ tim mạch và sức khỏe."),
    "E251": ("Muối natri nitrat bảo quản thịt muối", "Muối bảo quản dùng trong thịt ủ muối dài ngày và phô mai cứng, người tăng huyết áp cần tiết chế."),
    "E252": ("Muối kali nitrat bảo quản thịt muối", "Muối bảo quản truyền thống dùng trong giăm bông và xúc xích ủ khô."),
    "E260": ("Axit axetic điều chỉnh độ chua (Giấm ăn)", "Thành phần chính tạo vị chua tự nhiên của giấm ăn, dùng làm gia vị và bảo quản thực phẩm."),
    "E261": ("Muối kali axetat điều chỉnh độ chua", "Muối khoáng kali giúp cân bằng độ chua và bảo quản thực phẩm."),
    "E262": ("Muối natri axetat điều vị và bảo quản", "Muối natri của axit giấm dùng tạo hương vị giấm muối cho bánh snack và điều chỉnh độ chua."),
    "E263": ("Muối canxi axetat ổn định thực phẩm", "Muối canxi giúp chống mốc bánh mì và làm săn chắc kết cấu rau củ đóng hộp."),
    "E270": ("Axit lactic lên men tự nhiên", "Axit hữu cơ tự nhiên hình thành khi lên men sữa chua và dưa muối, tốt cho tiêu hóa và bảo quản tự nhiên."),
    "E280": ("Axit propionic chống mốc bánh nướng", "Axit hữu cơ tự nhiên giúp ngăn nấm mốc phát triển trong bánh mì lát và bánh ngọt đóng gói."),
    "E281": ("Muối natri propionat chống mốc bánh", "Muối natri bảo quản chống nấm mốc cho các sản phẩm bánh nướng công nghiệp."),
    "E282": ("Muối canxi propionat chống mốc bánh mì", "Phụ gia chống mốc phổ biến trong bánh mì tươi đóng gói sẵn, đồng thời bổ sung một phần canxi."),
    "E283": ("Muối kali propionat chống mốc bánh", "Muối kali bảo quản bánh nướng thay thế cho muối natri."),
    "E284": ("Axit boric (Chất hàn the cần tránh)", "Hợp chất nhóm hàn the có độc tính tích lũy, bị cấm sử dụng trong chế biến thực phẩm thông thường."),
    "E285": ("Hàn the (Muối natri tetraborat)", "Phụ gia tạo độ giòn dai bất hợp pháp trong giò chả, bún phở; có hại cho gan thận và sức khỏe."),
    "E290": ("Khí cacbonic tạo ga đồ uống", "Khí tạo bọt sủi tăm tự nhiên trong nước khoáng có ga, nước ngọt và bia."),
    "E296": ("Axit malic tạo vị chua trái cây", "Axit hữu cơ tự nhiên có nhiều trong quả táo xanh, dùng tạo vị chua thanh mát cho kẹo và nước trái cây."),
    "E297": ("Axit fumaric điều chỉnh độ chua", "Axit hữu cơ tự nhiên dùng tạo vị chua ổn định cho bột pha nước giải khát và nhân bánh."),
    "E300": ("Vitamin C chống oxy hóa tự nhiên", "Dưỡng chất vitamin C thiết yếu giúp ngăn thực phẩm bị thâm đen và tăng cường sức đề kháng."),
    "E301": ("Muối natri của vitamin C", "Dạng vitamin C trung tính không chua, dùng chống oxy hóa và giữ màu tươi cho thực phẩm."),
    "E302": ("Muối canxi của vitamin C", "Dạng kết hợp vitamin C và khoáng chất canxi dùng chống oxy hóa trong thực phẩm."),
    "E304": ("Dẫn xuất vitamin C tan trong dầu", "Chất chống oxy hóa có nguồn gốc từ vitamin C giúp bảo vệ dầu ăn và chất béo không bị ôi khét."),
    "E306": ("Chiết xuất giàu vitamin E tự nhiên", "Hỗn hợp vitamin E tự nhiên chiết xuất từ dầu thực vật giúp chống oxy hóa chất béo."),
    "E307": ("Vitamin E tự nhiên dạng alpha", "Hoạt chất vitamin E có hoạt tính sinh học cao nhất giúp bảo vệ màng tế bào và dầu thực phẩm."),
    "E310": ("Este chống oxy hóa dầu mỡ nhóm propyl", "Chất chống oxy hóa tổng hợp ngăn dầu mỡ thực phẩm bị ôi khét khi bảo quản lâu."),
    "E315": ("Axit đồng phân của vitamin C", "Chất chống oxy hóa giữ màu tươi cho thịt chế biến và đồ uống."),
    "E316": ("Muối natri chống oxy hóa giữ màu thịt", "Phụ gia chống oxy hóa giúp giữ màu hồng tự nhiên và giảm lượng nitrit cần dùng trong xúc xích."),
    "E319": ("Chất chống oxy hóa dầu chiên tổng hợp", "Phụ gia chống ôi khét dùng trong dầu ăn công nghiệp và mì ăn liền, cần kiểm soát đúng hàm lượng."),
    "E320": ("Chất chống oxy hóa chất béo tổng hợp nhóm một", "Phụ gia bảo quản chất béo và dầu thực vật khỏi bị oxy hóa, khuyến nghị hạn chế tiêu thụ nhiều."),
    "E321": ("Chất chống oxy hóa chất béo tổng hợp nhóm hai", "Phụ gia chống ôi dầu mỡ trong bánh quy, ngũ cốc và đồ chiên rán đóng gói."),
    "E322": ("Chất nhũ hóa tự nhiên từ đậu nành và lòng đỏ trứng", "Chất nhũ hóa tự nhiên giúp hòa quyện dầu và nước trong sô-cô-la, bánh kẹo và sữa bột; người dị ứng đậu nành hoặc trứng cần lưu ý nguồn gốc."),
    "E325": ("Muối natri lactat giữ ẩm thực phẩm", "Muối tự nhiên của axit lactic giúp giữ độ ẩm mềm và điều chỉnh độ chua cho thực phẩm."),
    "E326": ("Muối kali lactat giữ ẩm và điều vị", "Muối kali tự nhiên giúp bảo quản và giảm hàm lượng natri trong sản phẩm thịt."),
    "E327": ("Muối canxi lactat bổ sung khoáng chất", "Muối canxi dễ hấp thu dùng làm săn chắc trái cây cắt sẵn và bổ sung canxi."),
    "E330": ("Axit xitric tạo vị chua tự nhiên (Chanh)", "Axit hữu cơ tự nhiên có nhiều trong quả chanh và cam, dùng điều vị chua và bảo quản thực phẩm an toàn."),
    "E331": ("Muối natri xitrat cân bằng độ chua", "Muối natri của axit chanh giúp ổn định độ chua trong nước giải khát, sữa và phô mai."),
    "E332": ("Muối kali xitrat cân bằng độ chua", "Muối kali của axit chanh giúp điều chỉnh độ chua và bổ sung điện giải kali."),
    "E333": ("Muối canxi xitrat ổn định cấu trúc", "Muối canxi của axit chanh giúp làm đông chắc mứt quả và bổ sung canxi."),
    "E334": ("Axit tartaric tự nhiên từ quả nho", "Axit hữu cơ tự nhiên có trong quả nho và me, dùng tạo vị chua và làm bột nở."),
    "E338": ("Axit phốt phoric tạo vị chua nước ngọt", "Axit vô cơ dùng tạo vị chua đặc trưng trong nước ngọt có ga màu sẫm, dùng nhiều có thể ảnh hưởng hấp thu canxi."),
    "E339": ("Muối natri phốt phát giữ ẩm và ổn định", "Muối phốt phát giúp giữ nước, làm mềm phô mai và ổn định sữa đặc; chứa natri nên người tăng huyết áp cần lưu ý."),
    "E340": ("Muối kali phốt phát ổn định thực phẩm", "Muối khoáng kali phốt phát dùng ổn định bột kem pha cà phê và đồ uống thể thao."),
    "E341": ("Muối canxi phốt phát chống đông vón và tạo xốp", "Muối khoáng canxi dùng trong bột nở làm bánh và chống vón cục cho bột gia vị."),
    "E385": ("Phụ gia khóa kim loại bảo vệ màu và hương vị", "Chất ổn định giúp ngăn phản ứng đổi màu và ôi dầu trong sốt mayonnaise và đồ hộp."),
    "E400": ("Axit alginic chiết xuất từ tảo bẹ biển", "Chất tạo đặc và tạo màng tự nhiên chiết xuất từ tảo biển nâu."),
    "E401": ("Muối natri alginat tạo thạch từ tảo biển", "Phụ gia tạo đông và làm dày tự nhiên từ rong biển, thường dùng làm hạt thạch giòn và kem."),
    "E406": ("Chất tạo đông thạch rau câu tự nhiên", "Chất xơ hòa tan chiết xuất từ rong biển đỏ, dùng làm thạch rau câu, kẹo dẻo và món tráng miệng."),
    "E407": ("Chất làm dày chiết xuất tảo biển đỏ", "Polysacarit tự nhiên từ rong sụn biển giúp tạo độ sánh mịn cho sữa sô-cô-la, kem và thạch."),
    "E410": ("Chất làm dày nhựa hạt đậu minh quyết", "Chất xơ thực vật tự nhiên nghiền từ hạt đậu carob giúp kem và phô mai mềm mịn."),
    "E412": ("Chất làm dày chiết xuất hạt đậu guar", "Chất xơ hòa tan tự nhiên từ hạt đậu guar giúp tạo độ sánh cho nước sốt, kem và sữa chua."),
    "E414": ("Chất ổn định nhựa cây keo tự nhiên", "Chất xơ tự nhiên tiết ra từ thân cây keo, giúp giữ hương vị trong nước giải khát và kẹo ngậm."),
    "E415": ("Chất làm dày sinh học lên men đường", "Phụ gia tạo độ sánh mịn và ổn định nước sốt thu được từ quá trình lên men đường tự nhiên."),
    "E420": ("Đường rượu tự nhiên giữ ẩm và tạo ngọt nhẹ", "Chất tạo ngọt ít calo và giữ ẩm cho bánh kẹo; dùng quá nhiều cùng lúc có thể gây đầy bụng nhẹ."),
    "E421": ("Đường rượu tự nhiên chống dính kẹo", "Chất tạo ngọt mát ít hấp thu, thường phủ ngoài kẹo cao su và bánh kẹo không đường."),
    "E422": ("Hoạt chất giữ ẩm thực vật làm mềm bánh", "Hợp chất tự nhiên có nguồn gốc từ dầu thực vật giúp giữ bánh bông lan và kẹo mềm mịn, không bị khô."),
    "E440": ("Chất tạo đông chiết xuất từ vỏ táo và cam chanh", "Chất xơ hòa tan tự nhiên trong trái cây giúp làm đông mứt quả, thạch và ổn định sữa chua uống."),
    "E450": ("Muối điphốt phát tạo độ giòn dai và xốp bánh", "Nhóm muối phốt phát dùng làm bột nở bánh ngọt và tạo độ kết dính cho giò chả, xúc xích."),
    "E451": ("Muối triphốt phát giữ nước cho thực phẩm", "Phụ gia giữ ẩm và làm săn chắc bề mặt thủy hải sản, thịt chế biến."),
    "E452": ("Muối đa phốt phát ổn định cấu trúc", "Phụ gia tạo phức giữ ẩm và ổn định đạm trong sữa, phô mai và thịt nguội."),
    "E460": ("Chất xơ thực vật tinh khiết chống đông vón", "Chất xơ không hòa tan chiết xuất từ gỗ và bông thực vật, giúp chống vón cục phô mai bào và bổ sung chất xơ."),
    "E466": ("Dẫn xuất chất xơ thực vật tạo độ sánh", "Chất ổn định nguồn gốc thực vật giúp kem không bị dăm đá và nước giải khát có độ sánh mịn."),
    "E471": ("Chất nhũ hóa từ axit béo dầu thực vật", "Phụ gia phổ biến giúp trộn đều chất béo và nước trong bánh mì, kem, bơ thực vật và kẹo sô-cô-la."),
    "E500": ("Muối nở natri cacbonat làm xốp bánh", "Muối khoáng kiềm quen thuộc (bột nở) giúp bánh quy và bánh nướng nở xốp mềm."),
    "E501": ("Muối kali cacbonat điều chỉnh độ kiềm", "Muối khoáng giúp tạo độ dai vàng tự nhiên cho sợi mì trứng và vỏ bánh trung thu."),
    "E503": ("Muối amoni cacbonat tạo xốp bánh quy", "Chất tạo xốp truyền thống giúp bánh quy giòn rụm và bay hơi hoàn toàn khi nướng chín."),
    "E508": ("Muối khoáng kali clorua thay thế muối ăn", "Muối khoáng cung cấp vị mặn tương tự muối ăn nhưng không chứa natri, phù hợp cho thực phẩm giảm muối."),
    "E509": ("Muối canxi clorua làm giòn rau củ và đông đậu phụ", "Khoáng chất canxi giúp làm đông sữa đậu nành thành đậu phụ và giữ độ giòn cho dưa chuột muối."),
    "E620": ("Axit glutamic tạo vị ngọt đạm tự nhiên", "Axit amin tự nhiên có nhiều trong cà chua, nấm và phô mai, mang lại vị ngọt đậm đà cho món ăn."),
    "E621": ("Bột ngọt (Mì chính điều vị)", "Muối natri của axit glutamic dùng làm gia vị tăng vị ngọt đạm; chứa natri và liên quan chuyển hóa đạm nên người tăng huyết áp hoặc bệnh gút cần tiết chế."),
    "E627": ("Chất siêu điều vị chiết xuất nấm và hải sản", "Muối natri guanylat giúp tăng mạnh vị ngọt thịt khi dùng kèm bột ngọt; người bệnh gút cần hạn chế vì chuyển hóa thành purin."),
    "E631": ("Chất siêu điều vị muối natri inosinat", "Chất điều vị đậm đà thường dùng trong mì ăn liền, hạt nêm và bánh snack; người bệnh gút hoặc axit uric cao cần lưu ý."),
    "E635": ("Hỗn hợp chất siêu điều vị tổng hợp", "Sự kết hợp hai muối điều vị E627 và E631 tạo vị ngọt thịt mạnh; người bệnh gút và tăng huyết áp nên tiết chế."),
    "E901": ("Sáp ong tự nhiên làm bóng bề mặt kẹo", "Sáp tự nhiên từ tổ ong dùng phủ bóng bảo vệ viên kẹo dẻo, sô-cô-la và trái cây tươi."),
    "E903": ("Sáp lá cọ tự nhiên làm bóng kẹo", "Sáp thực vật tự nhiên chiết xuất từ lá cây cọ giúp viên kẹo bọc đường sáng bóng và không chảy nước."),
    "E950": ("Chất tạo ngọt tổng hợp kali axêsunfam", "Chất tạo ngọt không calo bền nhiệt dùng trong nước ngọt ăn kiêng và kẹo không đường."),
    "E951": ("Chất tạo ngọt tổng hợp ít năng lượng", "Đường ăn kiêng ngọt gấp khoảng 200 lần đường mía dùng trong đồ uống không đường; không dùng cho người mắc chứng rối loạn chuyển hóa phenylketon niệu."),
    "E952": ("Đường hóa học tạo ngọt tổng hợp nhóm xyclamat", "Chất tạo ngọt nhân tạo dùng giới hạn trong một số sản phẩm giải khát và mứt quả."),
    "E953": ("Đường ăn kiêng dẫn xuất từ củ cải đường", "Chất tạo ngọt dịu từ đường tự nhiên biến đổi, ít gây sâu răng và tăng đường huyết chậm."),
    "E954": ("Đường hóa học tạo ngọt mạnh không năng lượng", "Chất tạo ngọt tổng hợp lâu đời ngọt gấp 300 lần đường mía, nên sử dụng ở mức độ vừa phải."),
    "E955": ("Chất tạo ngọt không năng lượng từ đường mía", "Chất tạo ngọt bền nhiệt chế biến từ đường mía, không sinh năng lượng và giữ vị ngọt thanh."),
    "E960": ("Đường cỏ ngọt tự nhiên không năng lượng", "Chiết xuất tạo ngọt hoàn toàn tự nhiên từ lá cây cỏ ngọt, không làm tăng đường huyết và rất phù hợp cho người ăn kiêng."),
    "E965": ("Đường rượu mạch nha tạo ngọt dịu", "Chất tạo ngọt từ tinh bột ngô và lúa mì dùng làm sô-cô-la và bánh kẹo giảm đường."),
    "E967": ("Đường rượu tự nhiên bảo vệ răng miệng", "Chất tạo ngọt tự nhiên từ vỏ gỗ sồi và bắp ngô, giúp ngăn ngừa vi khuẩn gây sâu răng trong kẹo cao su."),
    "E968": ("Đường rượu lên men tự nhiên không calo", "Chất tạo ngọt tự nhiên từ quá trình lên men đường trái cây, hầu như không chứa calo và êm dịu với hệ tiêu hóa."),
    "E1105": ("Hoạt chất kháng khuẩn tự nhiên từ lòng trắng trứng", "Enzym tự nhiên chiết xuất từ lòng trắng trứng gà giúp bảo quản phô mai; có nguy cơ gây dị ứng với người dị ứng trứng."),
    "E1400": ("Tinh bột thực vật biến tính làm sánh thực phẩm", "Tinh bột sắn, ngô hoặc khoai tây được xử lý nhiệt nhẹ để tạo độ sánh mịn ổn định cho súp và nước sốt."),
    "E1412": ("Tinh bột biến tính liên kết phốt phát", "Tinh bột thực vật giúp tạo độ dai mịn cho tương ớt, sốt mayonnaise và chả cá."),
    "E1414": ("Tinh bột biến tính axetyl hóa liên kết phốt phát", "Tinh bột ổn định giúp thực phẩm đông lạnh và nước sốt không bị tách nước khi rã đông."),
    "E1420": ("Tinh bột thực vật biến tính giữ ẩm", "Tinh bột thực vật giúp sợi mì ăn liền dai ngon và bánh nướng mềm xốp."),
    "E1422": ("Tinh bột biến tính chịu nhiệt cho sốt và sữa chua", "Phụ gia tinh bột thực vật giúp sữa chua, tương cà và sốt trộn salad giữ cấu trúc sánh mịn."),
    "E1442": ("Tinh bột biến tính ổn định thực phẩm đông lạnh", "Tinh bột thực vật cao cấp giúp nhân bánh, kem và sữa chua giữ độ bóng mượt."),
}

# Curated Vietnamese & English titles and descriptions for key FoodOn/CHEBI concepts
CONCEPT_CATALOG = {
    # Sugars & Sweeteners
    "CHEBI:17992": ("Đường mía tinh luyện (Đường kính)", "Sucrose (Refined Table Sugar)", "Đường ăn phổ biến chiết xuất từ mía hoặc củ cải đường; người bệnh tiểu đường hoặc cần kiểm soát cân nặng nên hạn chế.", "Common table sugar extracted from sugar cane or sugar beet; individuals with diabetes should limit intake."),
    "CHEBI:17234": ("Đường nho hấp thu nhanh", "Glucose (Dextrose)", "Đường đơn cung cấp năng lượng tức thì và làm tăng đường huyết nhanh, cần kiểm soát chặt ở người tiểu đường.", "Simple monosaccharide sugar that rapidly raises blood glucose levels; requires careful monitoring for diabetes."),
    "CHEBI:17634": ("Đường đơn tự nhiên", "D-Glucose", "Dạng đường đơn tự nhiên có trong trái cây chín và mật ong, hấp thu nhanh vào máu.", "Naturally occurring simple sugar found in ripe fruits and honey, rapidly absorbed into the bloodstream."),
    "CHEBI:28757": ("Đường trái cây tự nhiên", "Fructose (Fruit Sugar)", "Đường đơn có độ ngọt cao tự nhiên trong trái cây và mật ong; tiêu thụ lượng lớn trong nước ngọt công nghiệp dễ làm tăng mỡ gan và đường huyết.", "High-sweetness natural fruit sugar; excessive intake in processed syrups and beverages impacts blood glucose and metabolism."),
    "CHEBI:15824": ("Đường trái cây", "Fructose", "Đường đơn tự nhiên có vị ngọt đậm trong hoa quả và mật ong.", "Naturally occurring simple fruit sugar with high sweetness intensity."),
    "CHEBI:17306": ("Đường mạch nha", "Maltose (Malt Sugar)", "Đường đôi hình thành từ quá trình thủy phân tinh bột ngũ cốc và mầm lúa mạch, làm tăng đường huyết khi tiêu hóa.", "Disaccharide sugar formed from cereal starch hydrolysis and malted grains; contributes to glycemic load."),
    "CHEBI:17716": ("Đường sữa tự nhiên", "Lactose (Milk Sugar)", "Đường tự nhiên có trong sữa bò và các chế phẩm từ sữa; cần lưu ý với người bất dung nạp đường sữa, dị ứng sữa hoặc tiểu đường.", "Natural disaccharide sugar found in mammalian milk and dairy products; relevant for dairy allergy, lactose intolerance, and diabetes."),
    "CHEBI:28260": ("Đường đơn từ sữa", "Galactose", "Đường đơn cấu thành nên đường sữa tự nhiên, chuyển hóa thành năng lượng trong cơ thể.", "Monosaccharide component of dairy lactose metabolized as a carbohydrate energy source."),
    "FOODON:00005790": ("Siro đường nho tinh luyện", "Glucose Syrup", "Siro đường đặc chế biến từ thủy phân tinh bột dùng trong bánh kẹo và kem, có chỉ số đường huyết cao.", "Concentrated sweetener syrup produced by starch hydrolysis, widely used in confectionery with a high glycemic index."),
    "FOODON:03301061": ("Siro ngô công nghiệp", "Corn Syrup", "Siro tạo ngọt chế biến từ tinh bột ngô thường dùng trong nước ngọt và bánh kẹo đóng gói; người tiểu đường cần tránh.", "Sweetener syrup derived from corn starch used in soft drinks and packaged snacks; cautioned for diabetes."),
    "FOODON:03301847": ("Siro mía đường", "Cane Syrup", "Siro ngọt đậm cô đặc từ nước mía ép, chứa hàm lượng đường cao.", "Concentrated sweet syrup made from sugar cane juice with high sugar content."),
    "FOODON:00005587": ("Siro mạch nha ngũ cốc", "Malt Syrup", "Siro ngọt dẻo chế biến từ mầm đại mạch và ngũ cốc, cần lưu ý với người tiểu đường.", "Viscous sweet syrup extracted from sprouted barley and cereal grains."),
    "FOODON:00001178": ("Mật ong tự nhiên", "Natural Honey", "Chất tạo ngọt tự nhiên giàu hương vị từ mật hoa nhưng vẫn chứa hàm lượng đường đơn cao, người tiểu đường cần dùng chừng mực.", "Natural floral sweetener rich in simple sugars (fructose and glucose); moderate intake advised for diabetes."),
    "CHEBI:83163": ("Mật rỉ đường mía", "Molasses", "Mật đường sánh đặc màu nâu sẫm thu được khi tinh luyện đường mía, giàu khoáng chất nhưng chứa nhiều đường.", "Dark viscous syrup byproduct of sugar cane refining containing sucrose and minerals."),
    "FOODON:00001083": ("Gia vị đường ăn", "Sugar Condiment", "Nhóm các loại đường gia vị dùng nêm nếm và tạo ngọt trực tiếp trong chế biến thực phẩm.", "Culinary sugar condiments used directly for sweetening foods and beverages."),
    "FOODON:00002300": ("Chất tạo ngọt thực phẩm", "Food Sweetener", "Nhóm nguyên liệu và phụ gia dùng để tạo vị ngọt cho thực phẩm và đồ uống.", "Ingredients and additives used to impart sweetness to foods and beverages."),
    "FOODON:03303225": ("Siro tạo ngọt", "Sweetener Syrup", "Dung dịch đường cô đặc dùng làm nguyên liệu tạo ngọt và giữ ẩm trong thực phẩm.", "Concentrated liquid sugar solution used for sweetening and moisture retention in foods."),

    # Salts & Sodium
    "CHEBI:26710": ("Muối ăn tinh luyện (Natri clorua)", "Sodium Chloride (Table Salt)", "Muối ăn thông thường cung cấp điện giải natri; tiêu thụ thừa làm tăng huyết áp và gánh nặng cho tim mạch, thận.", "Standard culinary table salt; excessive sodium intake increases blood pressure and cardiovascular risk."),
    "FOODON:03309954": ("Muối ăn gia vị", "Table Salt", "Muối ăn dùng nêm nếm hàng ngày, người bệnh tăng huyết áp cần kiểm soát lượng dùng dưới khuyến nghị.", "Everyday culinary table salt; sodium restriction is advised for hypertension management."),
    "FOODON:00002215": ("Sản phẩm muối thực phẩm", "Salt Food Product", "Nhóm các sản phẩm muối ăn và muối gia vị dùng trong chế biến thực phẩm.", "Culinary salt products and salted seasonings used in food preparation."),
    "CHEBI:24866": ("Muối khoáng thực phẩm", "Mineral Salt", "Nhóm hợp chất muối khoáng vô cơ và hữu cơ có mặt trong nguyên liệu thực phẩm.", "Inorganic and organic mineral salts present in food ingredients and additives."),
    "CHEBI:38700": ("Muối natri hữu cơ", "Organic Sodium Salt", "Nhóm muối hữu cơ chứa nguyên tố natri dùng làm chất điều vị hoặc bảo quản; người tăng huyết áp cần lưu ý tổng lượng natri.", "Class of organic sodium salts used as flavor enhancers or preservatives; contributes to dietary sodium load."),
    "CHEBI:26708": ("Hợp chất chứa natri", "Sodium Compound", "Thành phần phân tử chứa nguyên tố natri cần lưu ý trong chế độ ăn giảm mặn cho người tăng huyết áp.", "Chemical entity containing sodium relevant to low-sodium dietary management for hypertension."),

    # Fats & Cholesterol
    "CHEBI:16113": ("Mỡ máu (Cholesterol động vật)", "Cholesterol", "Chất béo sterol có trong mỡ động vật, lòng đỏ trứng và nội tạng; người rối loạn mỡ máu hoặc bệnh tim mạch cần kiểm soát.", "Dietary sterol lipid present in animal fats, egg yolks, and organ meats; intake should be monitored for high cholesterol."),
    "CHEBI:26607": ("Axit béo bão hòa", "Saturated Fatty Acid", "Nhóm chất béo no thường đông đặc ở nhiệt độ phòng (mỡ động vật, dầu cọ, dầu dừa), ăn nhiều làm tăng mỡ máu xấu.", "Saturated fats typically solid at room temperature (animal fats, palm oil, coconut oil) associated with elevated LDL cholesterol."),
    "FOODON:02010033": ("Mỡ động vật", "Animal Fat", "Chất béo tách từ mô mỡ động vật chứa hàm lượng chất béo bão hòa và cholesterol cao.", "Lipid tissue derived from animals containing high levels of saturated fat and dietary cholesterol."),
    "FOODON:03302051": ("Mỡ heo (Mỡ lợn)", "Pork Lard", "Mỡ thắng từ mô mỡ heo dùng chiên xào, giàu axit béo bão hòa nên người mỡ máu cao cần hạn chế.", "Rendered pork fat high in saturated fatty acids; moderation recommended for dyslipidemia."),
    "FOODON:00005450": ("Mỡ thịt heo", "Pork Fat", "Phần mô mỡ từ thịt heo chứa nhiều năng lượng và chất béo bão hòa.", "Adipose fat tissue from pork containing saturated lipids."),
    "FOODON:03310232": ("Dầu cọ thực vật", "Palm Oil", "Dầu thực vật ép từ quả cọ dùng rất phổ biến trong mì ăn liền và bánh quy, có tỷ lệ chất béo bão hòa cao.", "Vegetable oil extracted from oil palm fruit widely used in instant noodles and baked goods, high in saturated fat."),
    "FOODON:03301829": ("Dầu cọ tinh luyện", "Refined Palm Oil", "Dầu cọ đã qua tinh luyện bền nhiệt khi chiên rán công nghiệp nhưng giàu axit béo bão hòa.", "Refined palm oil with high thermal stability for industrial frying, rich in saturated fatty acids."),
    "FOODON:00003211": ("Dầu nhân cọ hyđrô hóa", "Hydrogenated Palm Kernel Oil", "Dầu hạt cọ đã qua xử lý làm cứng để tạo độ béo ngậy cho kem thực vật và nhân bánh, chứa nhiều chất béo bão hòa.", "Hydrogenated palm kernel oil used in confectionery fillings and non-dairy creamers, very high in saturated fat."),
    "FOODON:00003213": ("Dầu dừa hyđrô hóa", "Hydrogenated Coconut Oil", "Dầu dừa làm cứng dùng trong bánh kẹo công nghiệp, người mỡ máu cao nên hạn chế.", "Hydrogenated coconut oil used in processed confectionery; high in saturated fatty acids."),
    "FOODON:00002078": ("Dầu mỡ cọ tinh luyện", "Refined Palm Fat", "Chất béo tinh luyện từ quả cọ dùng làm shortening và bơ thực vật trong làm bánh.", "Refined palm fat fraction used as shortening and bakery fat."),
    "FOODON:00001023": ("Bơ sữa động vật", "Dairy Butter", "Bơ chế biến từ kem sữa bò tươi, chứa cả đạm sữa gây dị ứng và chất béo bão hòa.", "Traditional butter churned from cow's milk cream; contains dairy allergens and saturated milk fat."),
    "FOODON:03310351": ("Bơ (Bơ sữa động vật)", "Butter (Dairy Butter)", "Bơ chế biến từ kem sữa bò tươi, chứa đạm sữa bò (Casein, Whey) và đường sữa (Lactose) gây dị ứng sữa.", "Dairy butter churned from cow's milk cream; contains cow's milk proteins and lactose triggering dairy allergy."),
    "FOODON:03306867": ("Bơ đậu phộng (Bơ lạc)", "Peanut Butter", "Bơ nghiền từ hạt đậu phộng rang, thuộc nhóm tác nhân gây dị ứng đậu phộng nghiêm trọng.", "Spread ground from roasted peanuts; potent trigger for peanut allergy."),
    "FOODON:00002681": ("Chất béo từ sữa bò", "Milk Fat (Butterfat)", "Thành phần chất béo tự nhiên tách từ sữa động vật có vú.", "Natural lipid fraction of mammalian milk used in dairy products and bakery."),
    "CHEBI:15756": ("Axit béo palmitic (Chất béo no)", "Palmitic Acid (Saturated Fat)", "Axit béo bão hòa phổ biến nhất trong dầu cọ, mỡ thịt và bơ sữa.", "Major saturated fatty acid occurring in palm oil, meats, and dairy fats."),
    "CHEBI:28842": ("Axit béo stearic (Chất béo no)", "Stearic Acid (Saturated Fat)", "Axit béo bão hòa chuỗi dài có nhiều trong mỡ bò, mỡ heo và bơ ca cao.", "Long-chain saturated fatty acid abundant in animal tallow, lard, and cocoa butter."),
    "CHEBI:28875": ("Axit béo myristic (Chất béo no)", "Myristic Acid (Saturated Fat)", "Axit béo bão hòa có trong dầu dừa, dầu nhân cọ và chất béo sữa, dễ làm tăng mỡ máu.", "Saturated fatty acid found in coconut oil, palm kernel oil, and butterfat."),
    "CHEBI:30805": ("Axit béo lauric (Chất béo no)", "Lauric Acid (Saturated Fat)", "Axit béo bão hòa chính trong dầu dừa và dầu nhân cọ.", "Primary medium-chain saturated fatty acid in coconut oil and palm kernel oil."),
    "CHEBI:35366": ("Axit béo thực phẩm", "Fatty Acid", "Thành phần cấu tạo chính của các loại dầu thực vật, mỡ động vật và chất nhũ hóa thực phẩm.", "Carboxylic acid lipid building block of dietary fats, oils, and food emulsifiers."),

    # Allergens & Common Ingredients
    "FOODON:00003206": ("Đậu phộng (Hạt lạc)", "Peanut (Groundnut)", "Tác nhân gây dị ứng thực phẩm nghiêm trọng hàng đầu; người dị ứng đậu phộng tuyệt đối tránh sử dụng.", "Major high-risk food allergen; individuals with peanut allergy must strictly avoid."),
    "FOODON:00002099": ("Chế phẩm từ đậu phộng (Lạc)", "Peanut Food Product", "Thực phẩm hoặc nguyên liệu chế biến từ hạt đậu phộng (bơ lạc, kẹo lạc, dầu lạc thô) có nguy cơ gây dị ứng cao.", "Food ingredient or product derived from peanuts carrying severe allergic reaction risk."),
    "FOODON:00003207": ("Đậu phộng rang (Lạc rang)", "Roasted Peanut", "Hạt đậu phộng đã qua rang nhiệt, tính gây dị ứng của đạm đậu phộng càng mạnh hơn sau khi rang.", "Heat-roasted peanuts with potent allergenic proteins."),
    "FOODON:03301415": ("Hạt đậu nành (Đỗ tương)", "Soybean", "Nguyên liệu giàu đạm thực vật rất phổ biến nhưng nằm trong nhóm 8 tác nhân gây dị ứng thực phẩm chính.", "Widely used plant protein source and one of the eight major food allergens."),
    "FOODON:00002266": ("Chế phẩm từ đậu nành", "Soybean Food Product", "Thực phẩm chế biến từ đậu nành (sữa đậu nành, đậu phụ, đạm đậu nành, nước tương) cần lưu ý với người dị ứng đậu nành.", "Soy-derived food products and ingredients (tofu, soy milk, soy protein) triggering soy allergy."),
    "FOODON:00002783": ("Hạt đậu nành khô", "Dried Soybean", "Hạt đỗ tương khô dùng ép dầu, làm sữa hạt, bột đậu nành và nguyên liệu thực phẩm.", "Whole dried soybeans used for soy flour, soy milk, and protein extraction."),
    "FOODON:00001256": ("Sản phẩm từ sữa động vật", "Dairy Food Product", "Nhóm thực phẩm chế biến từ sữa (sữa tươi, phô mai, sữa chua, váng sữa) chứa đạm sữa và đường sữa.", "Milk-derived food products (milk, cheese, yogurt, cream) containing dairy proteins and lactose."),
    "FOODON:00001257": ("Sữa bò và chế phẩm từ sữa", "Milk & Dairy-Based Product", "Thực phẩm chứa sữa bò hoặc dẫn xuất từ sữa, là tác nhân gây dị ứng sữa phổ biến ở trẻ nhỏ và người lớn.", "Cow's milk and dairy-based ingredients triggering milk protein allergy and lactose sensitivity."),
    "FOODON:00002174": ("Sữa bột nguyên kem hoặc tách béo", "Powdered Milk", "Sữa bò cô đặc sấy khô dạng bột dùng rất nhiều trong bánh kẹo, sô-cô-la và ngũ cốc; chứa đạm sữa gây dị ứng.", "Spray-dried cow's milk powder widely used in bakery, confectionery, and beverages; contains milk allergens."),
    "FOODON:03315518": ("Đạm váng sữa bò", "Dairy Whey Protein", "Phần đạm hòa tan tách ra từ sữa bò trong quá trình làm phô mai; người dị ứng đạm sữa bò cần tránh.", "Soluble dairy protein fraction separated during cheese making; triggers cow's milk allergy."),
    "FOODON:03420180": ("Đạm sữa bò tự nhiên", "Casein (Milk Protein)", "Loại đạm chính chiếm 80% tổng lượng đạm trong sữa bò, tác nhân chính gây dị ứng sữa.", "Predominant phosphoprotein accounting for 80% of cow's milk protein and a primary dairy allergen."),
    "FOODON:00001012": ("Sữa bột công thức", "Powdered Milk Formula", "Sản phẩm dinh dưỡng dạng bột chế biến từ nền sữa bò.", "Formulated nutrition powder based on cow's milk proteins."),
    "FOODON:00001274": ("Trứng và chế phẩm từ trứng", "Egg Food Product", "Trứng gia cầm và bột trứng dùng trong bánh ngọt, sốt mayonnaise, mì sợi; thuộc nhóm gây dị ứng chính.", "Avian eggs and egg-derived ingredients used in bakery, noodles, and mayonnaise; major food allergen."),
    "FOODON:00004428": ("Trứng vịt", "Duck Egg", "Trứng gia cầm giàu đạm dùng trong làm bánh (trứng muối) và món ăn, có tính gây dị ứng tương tự trứng gà.", "Waterfowl egg used in culinary dishes and salted egg pastries; triggers avian egg allergy."),
    "FOODON:00002239": ("Tôm và chế phẩm từ tôm", "Shrimp & Prawn Product", "Hải sản giáp xác giàu đạm nhưng là tác nhân gây dị ứng hải sản mạnh nhất, đồng thời chứa nhiều purin không tốt cho người bệnh gút.", "Crustacean shellfish ingredient that triggers severe seafood allergy and contains high purines affecting gout."),
    "FOODON:00001248": ("Cá và chế phẩm từ cá", "Fish Food Product", "Thực phẩm chế biến từ cá (chả cá, cá hộp, nước mắm, bột cá) thuộc nhóm gây dị ứng thủy hải sản.", "Fish and fish-derived ingredients belonging to the major seafood allergen group."),
    "FOODON:00002679": ("Thịt cá phi lê", "Fish Fillet", "Phần thịt cá tách xương giàu đạm, cần lưu ý với người có cơ địa dị ứng cá và hải sản.", "Boneless fish flesh cut; triggers fish and seafood allergic reactions."),
    "FOODON:03420177": ("Đạm ngũ cốc (Gluten)", "Gluten Protein", "Hỗn hợp đạm tạo độ dẻo dai có trong lúa mì, lúa mạch đen và đại mạch; gây phản ứng ở người dị ứng gluten hoặc bệnh Celiac.", "Structural protein complex in wheat, barley, and rye responsible for dough elasticity; triggers gluten allergy and celiac disease."),
    "FOODON:03310809": ("Đạm lúa mì (Gluten lúa mì)", "Wheat Gluten", "Đạm chiết xuất từ bột mì dùng làm mì căn và tạo độ dai cho thực phẩm chay, bánh mì.", "Concentrated protein isolated from wheat flour; must be avoided by individuals with wheat or gluten sensitivity."),
    "FOODON:00001210": ("Bột mì tinh luyện", "Wheat Flour", "Nguyên liệu chính trong bánh mì, bánh quy, mì ăn liền và vỏ bánh; chứa gluten lúa mì gây dị ứng.", "Milled wheat flour used in bread, pasta, instant noodles, and pastries; contains gluten allergens."),
    "FOODON:00001141": ("Sản phẩm từ lúa mì", "Wheat Food Product", "Nhóm thực phẩm chế biến từ hạt lúa mì có chứa đạm gluten.", "Food products manufactured from wheat grain containing gluten proteins."),
    "FOODON:00003523": ("Hạt hạnh nhân", "Almond", "Loại hạt cây giàu dinh dưỡng thường dùng trong sô-cô-la, sữa hạt và bánh ngọt; thuộc nhóm dị ứng hạt cây.", "Nutrient-dense tree nut widely used in confectionery, bakery, and plant milks; major tree nut allergen."),
    "FOODON:03301364": ("Hạt óc chó", "Walnut", "Hạt cây giàu axit béo omega-3 dùng trong bánh nướng và ngũ cốc, có thể gây dị ứng nhóm hạt cây.", "Tree nut rich in omega-3 fatty acids used in baking and granola; triggers tree nut allergy."),
    "FOODON:00003615": ("Hạt điều", "Cashew Nut", "Hạt cây phổ biến trong bánh kẹo và đồ ăn nhẹ tại Việt Nam, thuộc nhóm gây dị ứng hạt cây mạnh.", "Popular culinary tree nut capable of triggering severe tree nut allergic reactions."),
    "FOODON:00002933": ("Hạt phỉ", "Hazelnut (Filbert)", "Hạt cây tạo hương thơm đặc trưng trong kem sô-cô-la phết bánh và kẹo nhân hạt, thuộc nhóm dị ứng hạt cây.", "Aromatic tree nut commonly used in chocolate spreads and pralines; major tree nut allergen."),
    "FOODON:00003691": ("Hạt dẻ cười", "Pistachio Nut", "Hạt cây màu xanh lục dùng trong kem, bánh ngọt và đồ ăn vặt, thuộc nhóm dị ứng hạt cây.", "Green tree nut used in ice cream, pastries, and snacks; belongs to the tree nut allergen group."),
    "FOODON:00003003": ("Hạt mắc ca", "Macadamia Nut", "Hạt cây béo ngậy dùng trong bánh quy và sô-cô-la cao cấp, cần lưu ý với người dị ứng hạt cây.", "Rich buttery tree nut used in cookies and confectionery; triggers tree nut sensitivity."),
    "FOODON:00002232": ("Mè (Vừng) và chế phẩm từ mè", "Sesame Food Product", "Hạt mè, dầu mè và bơ mè dùng tạo hương thơm cho bánh mì, món Á; thuộc nhóm 9 tác nhân gây dị ứng thực phẩm.", "Sesame seeds, sesame oil, and tahini paste; recognized as a major food allergen."),
    "FOODON:00004578": ("Hạt mè (Vừng) tự nhiên", "Raw Sesame Seed", "Hạt vừng nguyên hạt rắc trên bánh mì, bánh tráng và món ăn, có thể gây phản ứng ở người dị ứng mè.", "Whole unhulled or hulled sesame seeds used in bakery and savory dishes; triggers sesame allergy."),
    "FOODON:00004525": ("Bơ mè (Sốt vừng nghiền)", "Sesame Butter (Tahini)", "Sốt kem béo nghiền từ hạt mè rang dùng trong nước chấm và sốt trộn, chứa đạm mè gây dị ứng.", "Paste ground from toasted sesame seeds; concentrated source of sesame allergens."),

    # Meat, Poultry & Animal Food Products in FoodOn
    "FOODON:00001006": ("Thịt động vật có vú (Thịt đỏ: Bò, Heo, Cừu)", "Mammalian Meat (Beef, Pork, Lamb)", "Nhóm thịt động vật có vú (thịt bò, thịt heo, thịt cừu, thịt dê) và các chế phẩm từ thịt đỏ; giàu đạm và nhân purin.", "Mammalian meat food products (beef, pork, lamb, goat) and red meat derivatives."),
    "FOODON:00001092": ("Thịt và sản phẩm động vật có xương sống", "Vertebrate Animal Meat Product", "Nhóm các loại thịt động vật có vú, thịt gia cầm và sản phẩm chế biến từ động vật có xương sống.", "Meat and food products derived from vertebrate animals including mammals and poultry."),
    "FOODON:00001134": ("Thịt bò và chế phẩm từ bò", "Beef & Bovine Meat Product", "Thịt bò tươi và các nguyên liệu chế biến từ bò (bò viên, nước cốt bò, mỡ bò); có thể gây dị ứng đạm thịt bò hoặc dị ứng thịt đỏ.", "Beef cuts and bovine meat derivatives (beef extract, beef tallow, ground beef); may trigger beef or red meat allergy."),
    "FOODON:00002574": ("Thịt bò (Thịt bò pha lóc)", "Beef (Butchery Cut of Beef)", "Thịt bò nguyên miếng hoặc thái lát dùng chế biến món ăn và thực phẩm đóng gói.", "Primal or retail cut of beef used in culinary dishes and packaged foods."),
    "FOODON:00001038": ("Thịt heo (Thịt lợn) và chế phẩm", "Pork Meat Product", "Thịt heo và các nguyên liệu chế biến từ heo (giăm bông, xúc xích heo, thịt xông khói, mỡ heo).", "Pork meat and swine-derived food ingredients (ham, pork sausage, bacon, lard)."),
    "FOODON:00001040": ("Thịt gà và chế phẩm từ gà", "Chicken Meat Product", "Thịt gà và các nguyên liệu chiết xuất từ gà (ức gà, bột thịt gà, nước cốt gà).", "Chicken meat and poultry-derived ingredients (chicken breast, chicken broth, chicken extract)."),
    "FOODON:03411457": ("Thịt gà tươi (Gia cầm)", "Chicken (Poultry)", "Thịt gia cầm phổ biến giàu đạm, dùng trong chế biến món ăn, hạt nêm và thực phẩm đóng gói.", "Common poultry meat used across fresh dishes, broths, seasonings, and packaged foods."),
    "FOODON:00001131": ("Thịt gia cầm (Gà, Vịt, Ngan, Ngỗng)", "Poultry Meat Product", "Nhóm thịt gia cầm (thịt gà, thịt vịt, gà tây, ngỗng) và các chế phẩm từ gia cầm.", "Poultry meat products including chicken, duck, turkey, and goose."),
    "FOODON:00001284": ("Thịt vịt và chế phẩm", "Duck Meat Product", "Thịt vịt và các sản phẩm chế biến từ vịt.", "Duck meat and waterfowl food products."),
    "FOODON:03411316": ("Thịt vịt tươi", "Duck Meat", "Thịt gia cầm họ thủy cầm giàu dinh dưỡng.", "Waterfowl poultry meat."),
    "FOODON:00001287": ("Thịt cừu và chế phẩm", "Sheep & Lamb Meat Product", "Thịt cừu và các sản phẩm chế biến từ cừu thuộc nhóm thịt đỏ động vật có vú.", "Lamb and mutton meat products belonging to the mammalian red meat group."),
    "FOODON:03411669": ("Thịt cừu non", "Lamb Meat", "Thịt cừu non thuộc nhóm thịt đỏ động vật có vú.", "Young sheep meat classified under mammalian red meat."),
    "FOODON:00005738": ("Thịt đỏ (Bò, Heo, Cừu, Nai)", "Red Meat (Mammalian Meat)", "Nhóm thịt từ động vật có vú như bò, heo, cừu, dê, nai; cần lưu ý với người dị ứng thịt đỏ hoặc bệnh gút, mỡ máu cao.", "Meat derived from mammals such as beef, pork, lamb, and venison; relevant for red meat allergy, gout, and high cholesterol."),
    "FOODON:00000072": ("Thịt băm (Thịt xay)", "Ground Mammalian Meat (Minced Meat)", "Thịt động vật có vú (thịt heo, thịt bò) xay hoặc băm nhuyễn dùng trong nhân bánh, xúc xích và thực phẩm chế biến.", "Finely minced or ground mammalian meat used in fillings, patties, sausages, and processed foods."),
    "FOODON:00001010": ("Thịt chế biến sẵn (Thịt nguội, Xúc xích, Giò chả)", "Processed Meat Product", "Nhóm sản phẩm thịt qua chế biến, ủ muối hoặc xông khói như xúc xích, giăm bông, thịt hộp, lạp xưởng.", "Cured, smoked, or processed meat products such as sausages, ham, bacon, and luncheon meat."),
    "FOODON:00001007": ("Xúc xích thịt / Lạp xưởng", "Meat Sausage Product", "Sản phẩm chế biến từ thịt xay nhuyễn nhồi vỏ kèm gia vị và muối bảo quản.", "Sausage product made from ground meat, fat, spices, and curing salts."),
    "FOODON:03310675": ("Thịt hộp (Thịt nguội đóng hộp)", "Luncheon Meat (Canned Meat)", "Thịt heo hoặc thịt bò xay nhuyễn tẩm gia vị đóng hộp tiệt trùng.", "Spiced minced pork or beef cooked and sealed in cans."),
    "FOODON:00002935": ("Thịt nai / Thịt hươu", "Venison (Deer Meat)", "Thịt động vật có vú họ hươu nai thuộc nhóm thịt đỏ.", "Game meat from deer belonging to the mammalian red meat family."),
    "FOODON:03309567": ("Thịt tươi sống", "Raw Meat", "Thịt động vật tươi sống chưa qua chế biến nhiệt.", "Uncooked raw animal meat."),
}

# Curated translations for common ontology parent classes in `get_lineage`
LINEAGE_PARENT_VI = {
    "FOODON:03412972": "Phụ gia thực phẩm",
    "FOODON:03411041": "Thành phần hóa học thực phẩm",
    "FOODON:03400323": "Phân loại quản lý phụ gia thực phẩm",
    "FOODON:03400324": "Phân loại phụ gia tiêu chuẩn Châu Âu",
    "FOODON:03400361": "Phân loại thực phẩm theo cơ quan quản lý",
    "FOODON:03460368": "Chất ổn định thực phẩm",
    "FOODON:03460371": "Phụ gia bổ sung trong thực phẩm",
    "FOODON:03460372": "Dẫn xuất chất xơ thực vật",
    "FOODON:00001714": "Hợp phần nguyên liệu thực phẩm",
    "FOODON:00002403": "Nguyên liệu thực phẩm",
    "FOODON:00001002": "Sản phẩm thực phẩm",
    "FOODON:00001015": "Thực phẩm nguồn gốc thực vật",
    "FOODON:00002131": "Thực phẩm thực vật tinh chế",
    "FOODON:00002196": "Thực phẩm tinh chế",
    "FOODON:03311737": "Thực phẩm chế biến sẵn",
    "FOODON:03413749": "Vi chất dinh dưỡng và khoáng chất bổ sung",
    "FOODON:03413751": "Nhóm vitamin bổ sung thực phẩm",
    "FOODON:03400342": "Tinh bột thực phẩm biến tính",
    "FOODON:00001172": "Sản phẩm từ các loại hạt",
    "FOODON:00001006": "Thịt động vật có vú (Thịt đỏ)",
    "FOODON:00001092": "Sản phẩm thịt động vật có xương sống",
    "FOODON:00004242": "Sản phẩm thực phẩm nguồn gốc động vật",
    "FOODON:00001134": "Thịt bò và chế phẩm từ bò",
    "FOODON:00001038": "Thịt heo (Thịt lợn) và chế phẩm",
    "FOODON:00002663": "Sản phẩm thực phẩm từ heo",
    "FOODON:00001132": "Nhóm thực phẩm họ heo",
    "FOODON:00001040": "Thịt gà và chế phẩm từ gà",
    "FOODON:00001131": "Thịt gia cầm (Gà, Vịt, Ngan)",
    "FOODON:00001283": "Sản phẩm từ gia cầm",
    "FOODON:00001251": "Thực phẩm nguồn gốc gia cầm",
    "FOODON:00001010": "Thịt chế biến sẵn",
    "FOODON:00001007": "Xúc xích thịt chế biến",
    "FOODON:00001605": "Sản phẩm xúc xích động vật",
    "FOODON:02000403": "Phần thịt bò nguyên miếng",
    "FOODON:00004530": "Phần nguyên liệu từ bò",
    "FOODON:02010107": "Phần thịt động vật",
    "FOODON:02010223": "Thịt động vật xay nhuyễn",
    "FOODON:02010216": "Phần thịt động vật",
    "FOODON:00004332": "Bộ phận động vật",
    "FOODON:00004335": "Bộ phận cơ thể động vật",
    "FOODON:00004328": "Bộ phận sinh vật",
    "FOODON:03420116": "Nguyên liệu sinh vật",
    "FOODON:03420164": "Nguyên liệu từ động vật",
    "CHEBI:24431": "Thực thể hóa học",
    "CHEBI:23367": "Thực thể phân tử",
    "CHEBI:25367": "Phân tử hợp chất",
    "CHEBI:59999": "Hợp chất hóa học",
    "CHEBI:60004": "Hỗn hợp hợp chất",
    "CHEBI:50860": "Hợp chất hữu cơ",
    "CHEBI:72695": "Phân tử hữu cơ",
    "CHEBI:24835": "Hợp chất vô cơ",
    "CHEBI:24839": "Muối vô cơ",
    "CHEBI:24868": "Muối hữu cơ",
    "CHEBI:38700": "Muối natri hữu cơ",
    "CHEBI:38702": "Muối natri vô cơ",
    "CHEBI:26714": "Muối natri",
    "CHEBI:26218": "Muối kali",
    "CHEBI:35156": "Muối canxi",
    "CHEBI:190295": "Muối canxi vô cơ",
    "CHEBI:190297": "Muối magie vô cơ",
    "CHEBI:190299": "Muối magie hữu cơ",
    "CHEBI:190300": "Muối phốt phát vô cơ",
    "CHEBI:190303": "Muối kali vô cơ",
    "CHEBI:47704": "Muối amoni",
    "CHEBI:16646": "Nhóm chất bột đường",
    "CHEBI:18059": "Nhóm chất béo",
    "CHEBI:18154": "Đa đường thực vật",
    "CHEBI:167559": "Chuỗi đa đường tự nhiên",
    "CHEBI:33836": "Hợp chất thơm hữu cơ",
    "CHEBI:24532": "Hợp chất dị vòng hữu cơ",
    "CHEBI:35701": "Hợp chất este hữu cơ",
    "CHEBI:22723": "Nhóm axit benzoic",
    "CHEBI:26191": "Nhóm đường rượu đa chức",
    "CHEBI:26195": "Hoạt chất đa phenol thực vật",
    "CHEBI:23044": "Nhóm sắc tố tự nhiên carotenoit",
    "CHEBI:23042": "Sắc tố tiền vitamin A",
    "CHEBI:60027": "Hợp chất cao phân tử",
    "CHEBI:26820": "Nhóm muối sunfat",
    "CHEBI:26020": "Nhóm muối phốt phát",
}

# Ordered phrase replacement rules to convert any remaining English chemical/food label into 100% pure Vietnamese
EN_TO_VI_PHRASE_RULES = [
    (r"\bthermally oxidized soya bean oil interacted with mono- and diglycerides of fatty(?: acids)?\b", "dầu đậu nành oxy hóa nhiệt kết hợp este axit béo"),
    (r"\bmixed acetic and tartaric acid esters of\s+mono- and diglycerides of fatty acids\b", "este hỗn hợp axit axetic và tartaric của chất béo"),
    (r"\bmono- and diacetyl tartaric acid esters of mono- and diglycerides of fatty acids\b", "este axit tartaric của chất béo thực vật"),
    (r"\bacetic acid esters of mono- and diglycerides of fatty acids\b", "este axit axetic của chất béo thực vật"),
    (r"\blactic acid esters of mono- and diglycerides of fatty acids\b", "este axit lactic của chất béo thực vật"),
    (r"\bcitric acid esters of mono- and diglycerides of fatty acids\b", "este axit xitric của chất béo thực vật"),
    (r"\btartaric acid esters of mono- and diglycerides of fatty acids\b", "este axit tartaric của chất béo thực vật"),
    (r"\bmono- and diglycerides of fatty acids\b", "chất nhũ hóa từ axit béo thực vật"),
    (r"\bsodium, potassium and calcium salts of fatty acids\b", "muối natri, kali và canxi của axit béo"),
    (r"\bmagnesium salts of fatty acids\b", "muối magie của axit béo"),
    (r"\bsucrose esters of fatty acids\b", "este đường mía của axit béo"),
    (r"\bpolyglycerol esters of fatty acids\b", "este đa glixerol của axit béo"),
    (r"\bpropane-1,2-diol esters of fatty acids\b", "este propylen glycol của axit béo"),
    (r"\bcross-linked sodium carboxy methyl cellulose, cross linked cellulose gum\b", "chất xơ thực vật biến tính liên kết ngang"),
    (r"\benzymatically hydrolysed carboxy methyl cellulose, enzymatically hydrolysed cellulose gum\b", "chất xơ thực vật thủy phân bằng enzym"),
    (r"\bpolyoxyethylene \(20\) sorbitan tristearate \(polysorbate 65\)\b", "chất nhũ hóa thực phẩm nhóm polysorbat 65"),
    (r"\bpolyoxyethylene \(40\) stearate\b", "chất nhũ hóa este axit béo nhóm 40"),
    (r"\bethyl ester of beta-apo-8'-carotenic acid \(c 30\)\b", "este sắc tố vàng cam nhóm carotenoit"),
    (r"\bbeta-apo-8'-carotenal \(c 30\)\b", "sắc tố vàng cam nhóm carotenoit"),
    (r"\bcopper complexes of chlorophyllins\b", "phức chất đồng của sắc tố diệp lục"),
    (r"\bprocessed euchema seaweed\b", "chất làm dày từ rong sụn biển chế biến"),
    (r"\bextracts of rosemary\b", "chiết xuất thảo mộc hương thảo chống oxy hóa"),
    (r"\btocopherol-rich extract\b", "chiết xuất giàu vitamin E tự nhiên"),
    (r"\bbeeswax, white and yellow\b", "sáp ong tự nhiên trắng và vàng"),
    (r"\bquillaja extract\b|\bquillaia extract\b", "chiết xuất vỏ cây tạo bọt tự nhiên"),
    (r"\bsalt of aspartame-acesulfame\b", "muối phức hợp chất tạo ngọt ít năng lượng"),
    (r"\bsteviol glycosides\b", "đường cỏ ngọt tự nhiên"),
    (r"\bmodified starch \(ec\)\b|\bmodified starch\b", "tinh bột thực vật biến tính"),
    (r"\boxidized starch\b|\boxidised starch\b", "tinh bột biến tính oxy hóa"),
    (r"\bacetylated distarch adipate\b", "tinh bột biến tính axetyl hóa liên kết adipat"),
    (r"\bacetylated distarch phosphate\b", "tinh bột biến tính axetyl hóa liên kết phốt phát"),
    (r"\bacetylated oxidised starch\b", "tinh bột biến tính oxy hóa axetyl hóa"),
    (r"\bacetylated starch\b", "tinh bột thực vật biến tính axetyl hóa"),
    (r"\bhydroxy propyl distarch phosphate\b", "tinh bột biến tính ổn định nhiệt"),
    (r"\bhydroxy propyl starch\b", "tinh bột thực vật biến tính giữ ẩm"),
    (r"\bphosphated distarch phosphate\b", "tinh bột biến tính đa liên kết phốt phát"),
    (r"\bdistarch phosphate\b", "tinh bột biến tính liên kết phốt phát"),
    (r"\bmonostarch phosphate\b", "tinh bột biến tính đơn phốt phát"),
    (r"\bstarch sodium octenyl succinate\b", "tinh bột biến tính nhũ hóa hương liệu"),
    (r"\bstarch aluminium octenyl succinate\b", "tinh bột biến tính chống đông vón"),
    (r"\blocust bean gum\b", "chất làm dày từ hạt đậu minh quyết"),
    (r"\bguar gum\b", "chất làm dày từ hạt đậu guar"),
    (r"\bxanthan gum\b", "chất làm dày sinh học lên men đường"),
    (r"\bgum arabic\b|\bacacia gum\b", "chất ổn định nhựa cây keo tự nhiên"),
    (r"\bkaraya gum\b", "chất làm dày nhựa cây tự nhiên nhóm karaya"),
    (r"\btara gum\b", "chất làm dày từ hạt cây họ đậu tara"),
    (r"\bgellan gum\b", "chất tạo đông sinh học lên men"),
    (r"\bcassia gum\b", "chất làm dày từ hạt thảo quyết minh"),
    (r"\btragacanth\b", "nhựa cây tự nhiên làm dày thực phẩm"),
    (r"\bkonjac\b", "bột củ nưa tạo thạch giàu chất xơ"),
    (r"\bsoybean hemicellulose\b", "chất xơ hòa tan chiết xuất từ đậu nành"),
    (r"\bcellulose product\b", "chất xơ thực vật tinh khiết"),
    (r"\bcarboxy methyl cellulose\b", "dẫn xuất chất xơ thực vật làm sánh"),
    (r"\bhydroxypropyl methylcellulose\b", "dẫn xuất chất xơ thực vật giữ ẩm"),
    (r"\bhydroxypropyl cellulose\b", "dẫn xuất chất xơ thực vật tạo màng"),
    (r"\bethyl methyl cellulose\b", "dẫn xuất chất xơ thực vật nhũ hóa"),
    (r"\bmethyl cellulose\b", "dẫn xuất chất xơ thực vật tạo đặc"),
    (r"\bethyl cellulose\b", "dẫn xuất chất xơ thực vật phủ bề mặt"),
    (r"\bbeta-cyclodextrin\b|\bcyclodextrin\b", "vòng đường tinh bột giữ hương tự nhiên"),
    (r"\bsucroglycerides\b", "chất nhũ hóa từ đường mía và dầu thực vật"),
    (r"\bpolyglycerol polyricinoleate\b", "chất nhũ hóa làm mịn sô-cô-la"),
    (r"\bsorbitan tristearate\b", "chất nhũ hóa giữ bóng sô-cô-la"),
    (r"\bcandelilla wax\b", "sáp thực vật tự nhiên làm bóng kẹo"),
    (r"\bcarnauba wax\b", "sáp lá cọ tự nhiên làm bóng"),
    (r"\bmicrocrystalline wax\b", "sáp tinh thể mịn phủ bảo vệ bề mặt"),
    (r"\boxidized polyethylene wax\b", "sáp phủ bảo vệ vỏ trái cây tươi"),
    (r"\bshellac\b", "nhựa cánh kiến tự nhiên làm bóng kẹo"),
    (r"\bmontan acid esters\b", "este sáp tự nhiên phủ bảo quản vỏ quả"),
    (r"\bhydrogenated poly-1-decene\b", "chất phủ bóng bề mặt thực phẩm"),
    (r"\bpolysorbate\s*(\d+)\b", r"chất nhũ hóa thực phẩm nhóm \1"),
    (r"\bdimethicone polymer\b|\bpolydimethylsiloxane polymer\b|\bsilicone polymer\b", "chất chống tạo bọt trong chế biến thực phẩm"),
    (r"\bpoly\(vinylpyrrolidone\)\b|\bpolyvinylpolypyrrolidone\b", "chất làm trong đồ uống và giữ cấu trúc viên"),
    (r"\bpolyvinyl alcohol \(pva\)\b", "màng phủ bảo vệ viên thực phẩm bổ sung"),
    (r"\bbasic methacrylate copolymer\b", "màng bao bảo vệ dưỡng chất"),
    (r"\bpullulan\b|\bpullulans\b", "màng tinh bột lên men tự nhiên làm thơm miệng"),
    (r"\bpolydextrose\b", "chất xơ hòa tan tạo độ đặc ít năng lượng"),
    (r"\binvertase\b", "enzym tự nhiên làm mềm nhân kẹo đường"),
    (r"\blysozyme\b", "enzym kháng khuẩn tự nhiên từ lòng trắng trứng"),
    (r"\b5'-ribonucleotides\b", "hợp chất điều vị tạo vị ngọt thịt"),
]

EN_WORD_TO_VI = {
    "food": "thực phẩm",
    "product": "sản phẩm",
    "products": "sản phẩm",
    "additive": "phụ gia",
    "additives": "phụ gia",
    "component": "thành phần",
    "material": "nguyên liệu",
    "chemical": "hóa học",
    "organic": "hữu cơ",
    "inorganic": "vô cơ",
    "molecular": "phân tử",
    "entity": "hợp chất",
    "substance": "chất",
    "mixture": "hỗn hợp",
    "compound": "hợp chất",
    "compounds": "hợp chất",
    "derivative": "dẫn xuất",
    "derivatives": "dẫn xuất",
    "acid": "axit",
    "acids": "axit",
    "salt": "muối",
    "salts": "muối",
    "ester": "este",
    "esters": "este",
    "sodium": "natri",
    "disodium": "đinatri",
    "trisodium": "trinatri",
    "monosodium": "mononatri",
    "potassium": "kali",
    "dipotassium": "đikali",
    "tripotassium": "trikali",
    "monopotassium": "monokali",
    "pentapotassium": "đa kali",
    "calcium": "canxi",
    "dicalcium": "đicanxi",
    "tricalcium": "tricanxi",
    "magnesium": "magie",
    "ammonium": "amoni",
    "monoammonium": "monoamoni",
    "triammonium": "triamoni",
    "aluminium": "nhôm",
    "aluminum": "nhôm",
    "iron": "sắt",
    "ferrous": "sắt",
    "ferric": "sắt",
    "copper": "đồng",
    "zinc": "kẽm",
    "tin": "thiếc",
    "silver": "bạc",
    "gold": "vàng",
    "titanium": "titan",
    "silicon": "silic",
    "boron": "bo",
    "sulfur": "lưu huỳnh",
    "sulphur": "lưu huỳnh",
    "phosphorus": "phốt pho",
    "nitrogen": "nitơ",
    "oxygen": "ôxy",
    "hydrogen": "hyđrô",
    "dihydrogen": "đihyđrô",
    "carbon": "cacbon",
    "helium": "khí hêli",
    "argon": "khí agon",
    "butane": "khí butan",
    "isobutane": "khí isobutan",
    "propane": "khí propan",
    "oxide": "ôxít",
    "oxides": "ôxít",
    "dioxide": "điôxít",
    "hydroxide": "hyđrôxít",
    "hydroxides": "hyđrôxít",
    "carbonate": "cacbonat",
    "bicarbonate": "bicacbonat",
    "chloride": "clorua",
    "dichloride": "điclorua",
    "sulfate": "sunfat",
    "sulphate": "sunfat",
    "sulfates": "sunfat",
    "sulfite": "sunfit",
    "sulphite": "sunfit",
    "disulfite": "đisunfit",
    "metabisulphite": "metabisunfit",
    "metabisulfite": "metabisunfit",
    "nitrite": "nitrit",
    "nitrate": "nitrat",
    "phosphate": "phốt phát",
    "diphosphate": "điphốt phát",
    "triphosphate": "triphốt phát",
    "polyphosphates": "đa phốt phát",
    "hydrogenphosphate": "hyđrô phốt phát",
    "dihydrogenphosphate": "đihyđrô phốt phát",
    "silicate": "silicat",
    "aluminosilicate": "nhôm silicat",
    "acetate": "axetat",
    "diacetate": "điaxetat",
    "triacetate": "triaxetat",
    "isobutyrate": "isobutyrat",
    "lactate": "lactat",
    "lactylate": "lactylat",
    "citrate": "xitrat",
    "tartrate": "tartrat",
    "metatartaric": "metatartaric",
    "malate": "malat",
    "adipate": "adipat",
    "adipic": "adipic",
    "succinate": "succinat",
    "succinic": "succinic",
    "fumaric": "fumaric",
    "propionate": "propionat",
    "propionic": "propionic",
    "benzoate": "benzoat",
    "benzoic": "benzoic",
    "sorbate": "sorbat",
    "sorbic": "sorbic",
    "ascorbate": "ascorbat",
    "ascorbic": "ascorbic",
    "isoascorbic": "isoascorbic",
    "erythorbate": "erythorbat",
    "gallate": "gallat",
    "alginate": "alginat",
    "alginic": "alginic",
    "gluconate": "gluconat",
    "gluconic": "gluconic",
    "glutamate": "glutamat",
    "diglutamate": "điglutamat",
    "glutamic": "glutamic",
    "guanylate": "guanylat",
    "guanylic": "guanylic",
    "inosinate": "inosinat",
    "inosine": "inosin",
    "stearate": "stearat",
    "tristearate": "tristearat",
    "palmitate": "palmitat",
    "oleate": "oleat",
    "fatty": "béo",
    "saturated": "bão hòa",
    "unsaturated": "không bão hòa",
    "polyunsaturated": "đa không bão hòa",
    "monounsaturated": "đơn không bão hòa",
    "lipid": "chất béo",
    "starch": "tinh bột",
    "sugar": "đường",
    "syrup": "siro",
    "sweetener": "chất tạo ngọt",
    "honey": "mật ong",
    "milk": "sữa",
    "dairy": "sữa",
    "butter": "bơ",
    "cheese": "phô mai",
    "whey": "váng sữa",
    "egg": "trứng",
    "wheat": "lúa mì",
    "flour": "bột",
    "bread": "bánh mì",
    "soybean": "đậu nành",
    "soy": "đậu nành",
    "soya": "đậu nành",
    "peanut": "đậu phộng",
    "almond": "hạnh nhân",
    "walnut": "óc chó",
    "cashew": "hạt điều",
    "hazelnut": "hạt phỉ",
    "pistachio": "hạt dẻ cười",
    "macadamia": "hạt mắc ca",
    "sesame": "hạt mè",
    "coconut": "dừa",
    "palm": "cọ",
    "oil": "dầu",
    "fat": "mỡ",
    "lard": "mỡ heo",
    "tallow": "mỡ bò",
    "meat": "thịt",
    "meats": "thịt",
    "red": "đỏ",
    "ground": "băm",
    "minced": "xay",
    "sausage": "xúc xích",
    "sausages": "xúc xích",
    "ham": "giăm bông",
    "bacon": "thịt xông khói",
    "steak": "bít tết",
    "roast": "quay nướng",
    "smoked": "xông khói",
    "cured": "ủ muối",
    "canned": "đóng hộp",
    "frozen": "đông lạnh",
    "cooked": "nấu chín",
    "broth": "nước hầm",
    "stock": "nước cốt hầm",
    "gravy": "nước sốt thịt",
    "soup": "súp",
    "stew": "món hầm",
    "pie": "bánh nhân",
    "ball": "viên",
    "meatball": "thịt viên",
    "meatballs": "thịt viên",
    "meatloaf": "thịt băm đúc lò",
    "patty": "miếng chả",
    "strip": "thái dải",
    "trimming": "phần thịt lọc",
    "luncheon": "nguội đóng hộp",
    "venison": "thịt nai",
    "lamb": "thịt cừu",
    "mutton": "thịt cừu",
    "veal": "thịt bê",
    "duck": "thịt vịt",
    "turkey": "gà tây",
    "goose": "thịt ngỗng",
    "goat": "thịt dê",
    "bovine": "bò",
    "porcine": "heo",
    "swine": "heo",
    "pig": "heo",
    "poultry": "gia cầm",
    "avian": "gia cầm",
    "mammalian": "động vật có vú",
    "vertebrate": "động vật",
    "pork": "thịt heo",
    "chicken": "thịt gà",
    "beef": "thịt bò",
    "fish": "cá",
    "shrimp": "tôm",
    "crab": "cua",
    "squid": "mực",
    "shellfish": "hải sản có vỏ",
    "crustacean": "giáp xác",
    "mollusc": "nhuyễn thể",
    "plant": "thực vật",
    "vegetable": "thực vật",
    "animal": "động vật",
    "natural": "tự nhiên",
    "refined": "tinh luyện",
    "processed": "chế biến",
    "dried": "sấy khô",
    "roasted": "rang",
    "raw": "tươi sống",
    "powdered": "dạng bột",
    "extract": "chiết xuất",
    "stabilizer": "chất ổn định",
    "nutrient": "dưỡng chất",
    "mineral": "khoáng chất",
    "polymer": "cao phân tử",
    "alcohol": "rượu hữu cơ",
    "alcohols": "rượu hữu cơ",
    "glycol": "glycol giữ ẩm",
    "glycerol": "glixerol giữ ẩm",
    "glyceryl": "glixeryl",
    "cellulose": "chất xơ thực vật",
    "gum": "nhựa thực vật",
    "wax": "sáp tự nhiên",
    "elemental": "nguyên tố",
    "hydrate": "ngậm nước",
    "dihydrate": "ngậm nước",
}


def _clean_kala_vi_terms(vi_terms: list[str]) -> list[str]:
    cleaned = []
    for t in vi_terms or []:
        t_str = t.strip()
        if not t_str or t_str.lower() in BAD_KALA_VI_TERMS:
            continue
        # Reject corrupted VNI/TCVN3 strings where closed diphthong 'ay'/'ây' is followed by another letter
        if re.search(r"[aâàảãáạấầẩẫậ]y[a-zà-ỹ]", t_str.lower()):
            continue
        # Skip broken spaced-out phonetic strings if better terms exist
        if re.search(r"[a-zA-Z]", t_str) and not any(ord(c) > 127 for c in t_str):
            # Pure ASCII without Vietnamese diacritics: skip unless it's vitamin
            if not t_str.lower().startswith("vitamin"):
                continue
        cleaned.append(t_str)
    return cleaned


def translate_lineage_label_vi(curie: str, label_en: str, label_vi: str = "") -> str:
    if curie in LINEAGE_PARENT_VI:
        return LINEAGE_PARENT_VI[curie]
    if curie in CONCEPT_CATALOG:
        return CONCEPT_CATALOG[curie][0]
    if label_vi and label_vi.lower() not in BAD_KALA_VI_TERMS and any(ord(c) > 127 for c in label_vi):
        return label_vi[0].upper() + label_vi[1:]
    return translate_en_phrase_to_vi(label_en)


def translate_en_phrase_to_vi(label_en: str, primary_code: str = "") -> str:
    code_up = (primary_code or "").upper()
    if code_up in ECODE_VI_CATALOG:
        return ECODE_VI_CATALOG[code_up][0]

    s = (label_en or "").strip().lower()
    if not s:
        return "Hợp phần thực phẩm"

    for pat, repl in EN_TO_VI_PHRASE_RULES:
        s = re.sub(pat, repl, s, flags=re.IGNORECASE)

    # Check pattern "<metal> <anion>" e.g. "potassium sorbate" -> "Muối kali sorbat"
    m_salt = re.match(
        r"^(sodium|disodium|trisodium|monosodium|potassium|dipotassium|tripotassium|monopotassium|pentapotassium|calcium|dicalcium|tricalcium|magnesium|ammonium|monoammonium|triammonium|aluminium|aluminum|ferrous|ferric|zinc|copper|tin(?:\(ii\))?)\s+([a-z0-9'\-\s]+)$",
        s,
    )
    if m_salt and "acid" not in m_salt.group(2):
        cation_en = m_salt.group(1).replace("(ii)", "")
        anion_en = m_salt.group(2).strip()
        cation_vi = EN_WORD_TO_VI.get(cation_en, cation_en)
        anion_words = [EN_WORD_TO_VI.get(w, w) for w in re.split(r"[\s\-]+", anion_en) if w]
        res = f"Muối {cation_vi} {' '.join(anion_words)}"
        res = re.sub(r"\s+", " ", res).strip()
        return res[0].upper() + res[1:]

    # Check pattern "<name> acid" -> "Axit <name>"
    m_acid = re.match(r"^([a-z0-9,\-'\s]+)\s+acids?$", s)
    if m_acid:
        stem = m_acid.group(1).strip()
        stem_words = [EN_WORD_TO_VI.get(w, w) for w in re.split(r"[\s\-]+", stem) if w]
        res = f"Axit {' '.join(stem_words)}"
        res = re.sub(r"\s+", " ", res).strip()
        return res[0].upper() + res[1:]

    # General word-by-word translation with cleanup of remaining chemical symbols
    tokens = re.findall(r"[a-zA-Z]+|\d+", s)
    vi_words = []
    for tok in tokens:
        low_tok = tok.lower()
        if low_tok in ("and", "or", "of", "the", "in", "with", "from", "based", "type", "ec", "usa", "fcf", "ac", "bk", "fk", "ht", "bn", "pn", "dc"):
            continue
        if low_tok in EN_WORD_TO_VI:
            mapped = EN_WORD_TO_VI[low_tok]
            if not vi_words or vi_words[-1] != mapped:
                vi_words.append(mapped)
        elif any(ord(c) > 127 for c in low_tok):
            vi_words.append(low_tok)

    if not vi_words:
        if code_up.startswith("E"):
            return f"Phụ gia thực phẩm nhóm {code_up}"
        return "Hợp phần nguyên liệu thực phẩm"

    # Reorder if "axit" or "muối" or "sản phẩm" or "thực phẩm" is at the end
    joined = " ".join(vi_words)
    joined = re.sub(r"\b([a-zà-ỹ]+)\s+axit\b", r"axit \1", joined)
    joined = re.sub(r"\b(natri|kali|canxi|magie|amoni|sắt|nhôm|kẽm)\s+muối\b", r"muối \1", joined)
    joined = re.sub(r"\s+", " ", joined).strip()
    return joined[0].upper() + joined[1:]


def format_clean_english_title(curie: str, label_en: str, primary_code: str = "") -> str:
    if curie in CONCEPT_CATALOG:
        return CONCEPT_CATALOG[curie][1]
    raw = (label_en or curie).replace("/", " / ").strip()
    raw = re.sub(r"\s*\(ec\)\s*", "", raw, flags=re.IGNORECASE)
    if not raw:
        return curie
    # Title-case words while preserving acronyms/roman numerals
    words = raw.split(" ")
    out = []
    for w in words:
        if not w:
            continue
        if w.lower() in ("of", "and", "or", "in", "with", "from", "to", "for") and out:
            out.append(w.lower())
        elif w.upper() in ("FCF", "AC", "BN", "PN", "FK", "HT", "BK", "DC", "PVA", "TBHQ", "EDTA", "IMP", "MSG", "II", "III", "IV"):
            out.append(w.upper())
        else:
            out.append(w[0].upper() + w[1:])
    return " ".join(out)


def build_monolingual_card_fields(
    curie: str,
    label_en: str,
    vi_terms: list[str],
    en_terms: list[str],
    lineage_nodes: list[dict],
    allergens: list[str],
    chronics: list[str],
    ecodes: list[str],
    risk_level: str,
    primary_code: str = "",
    preferred_vi_term: str = "",
) -> dict:
    """
    Produces strictly monolingual fields for both Vietnamese (`_vi`) and English (`_en`).
    """
    code_up = (primary_code or (ecodes[0] if ecodes else "")).upper()
    clean_vi_list = _clean_kala_vi_terms(vi_terms)

    # 1. Determine Title VI and Title EN
    if curie in CONCEPT_CATALOG:
        title_vi = CONCEPT_CATALOG[curie][0]
        title_en = CONCEPT_CATALOG[curie][1]
        base_desc_vi = CONCEPT_CATALOG[curie][2]
        base_desc_en = CONCEPT_CATALOG[curie][3]
    elif code_up in ECODE_VI_CATALOG:
        title_vi = ECODE_VI_CATALOG[code_up][0]
        title_en = format_clean_english_title(curie, label_en, code_up)
        base_desc_vi = ECODE_VI_CATALOG[code_up][1]
        base_desc_en = ""
    else:
        title_en = format_clean_english_title(curie, label_en, code_up)
        pref_clean = (preferred_vi_term or "").strip()
        if pref_clean and pref_clean.lower() not in BAD_KALA_VI_TERMS and any(ord(c) > 127 for c in pref_clean):
            title_vi = pref_clean[0].upper() + pref_clean[1:]
        elif clean_vi_list:
            # Prefer a multi-word descriptive Vietnamese term if available (e.g. "thịt vịt" over "vịt", "thịt cừu" over "cừu con")
            best_vi = next((t for t in clean_vi_list if "thịt" in t.lower() or len(t.split()) >= 2), clean_vi_list[0])
            title_vi = best_vi[0].upper() + best_vi[1:]
        else:
            title_vi = translate_en_phrase_to_vi(label_en, code_up)
        base_desc_vi = ""
        base_desc_en = ""

    # Ensure clean_vi_list always starts with title_vi so Vietnamese synonyms are never empty or English
    if title_vi.lower() not in [x.lower() for x in clean_vi_list]:
        clean_vi_list.insert(0, title_vi)

    # 2. Enrich lineage nodes with strictly monolingual display_label_vi and display_label_en
    enriched_lineage = []
    for idx, node in enumerate(lineage_nodes):
        n_curie = node.get("curie", "")
        n_en = node.get("label_en", "")
        n_vi_raw = node.get("label_vi", "")
        if idx == 0:
            disp_vi = title_vi
            disp_en = title_en
        else:
            disp_vi = translate_lineage_label_vi(n_curie, n_en, n_vi_raw)
            disp_en = format_clean_english_title(n_curie, n_en)
        enriched_lineage.append({
            **node,
            "label_vi": disp_vi,
            "display_label_vi": disp_vi,
            "display_label_en": disp_en,
        })

    # 3. Build 100% Vietnamese Description (`description_vi`)
    desc_vi_parts = []
    if base_desc_vi:
        desc_vi_parts.append(base_desc_vi)
    else:
        parent_vi_names = [
            n["display_label_vi"]
            for n in enriched_lineage[1:3]
            if n.get("display_label_vi") and n["display_label_vi"].lower() != title_vi.lower()
        ]
        if code_up.startswith("E"):
            if risk_level == "safe":
                desc_vi_parts.append(f"Phụ gia thực phẩm mã {code_up} thuộc nhóm dưỡng chất và thành phần an toàn trong chế biến thực phẩm.")
            elif risk_level == "high":
                desc_vi_parts.append(f"Phụ gia thực phẩm mã {code_up} thuộc nhóm hợp chất tổng hợp hoặc cần kiểm soát hàm lượng sử dụng, khuyến nghị hạn chế tiêu thụ nhiều.")
            else:
                desc_vi_parts.append(f"Phụ gia thực phẩm mã {code_up} dùng làm chất ổn định, tạo cấu trúc hoặc bảo quản trong giới hạn cho phép.")
        elif parent_vi_names:
            desc_vi_parts.append(f"Phân loại dinh dưỡng: {' → '.join(parent_vi_names)}.")
        else:
            desc_vi_parts.append(f"Thành phần nguyên liệu thực phẩm ({title_vi}).")

    if allergens:
        al_vi = [ALLERGEN_DISPLAY_NAMES_VI.get(a, a) for a in allergens]
        desc_vi_parts.append(f"Cảnh báo dị ứng: {', '.join(al_vi)}.")
    if chronics:
        ch_vi = [CHRONIC_DISPLAY_NAMES_VI.get(c, c) for c in chronics]
        desc_vi_parts.append(f"Lưu ý sức khỏe: {', '.join(ch_vi)}.")

    description_vi = " ".join(desc_vi_parts)

    # 4. Build 100% English Description (`description_en`)
    desc_en_parts = []
    if base_desc_en:
        desc_en_parts.append(base_desc_en)
    else:
        parent_en_names = [
            n["display_label_en"]
            for n in enriched_lineage[1:3]
            if n.get("display_label_en") and n["display_label_en"].lower() != title_en.lower()
        ]
        if code_up.startswith("E"):
            if risk_level == "safe":
                desc_en_parts.append(f"Food additive {code_up} classified as a safe nutritional or natural food component.")
            elif risk_level == "high":
                desc_en_parts.append(f"Food additive {code_up} is a regulated synthetic or chemical additive; moderate consumption is advised for sensitive individuals.")
            else:
                desc_en_parts.append(f"Food additive {code_up} used as a food-grade stabilizer, emulsifier, or functional ingredient within permitted limits.")
        if parent_en_names:
            desc_en_parts.append(f"Ontology classification: {' → '.join(parent_en_names)}.")

    if allergens:
        al_en = [ALLERGEN_DISPLAY_NAMES_EN.get(a, a) for a in allergens]
        desc_en_parts.append(f"Allergen warning: {', '.join(al_en)}.")
    if chronics:
        ch_en = [CHRONIC_DISPLAY_NAMES_EN.get(c, c) for c in chronics]
        desc_en_parts.append(f"Health advisory: {', '.join(ch_en)}.")

    if not desc_en_parts:
        desc_en_parts.append(f"Classified food component ({title_en}) in the FoodOn ontology.")

    description_en = " ".join(desc_en_parts)

    return {
        "title_vi": title_vi,
        "title_en": title_en,
        "description_vi": description_vi,
        "description_en": description_en,
        "clean_vi_terms": clean_vi_list[:8],
        "clean_en_terms": [format_clean_english_title("", t) for t in (en_terms or [label_en])[:8] if t],
        "enriched_lineage": enriched_lineage,
    }


ALLERGEN_RELATED_INGREDIENTS_VI = {
    "milk": "Sữa bột, Sữa tươi, Đạm váng sữa, Đạm sữa bò, Đường sữa, Phô mai, Kem sữa, Sữa chua, Bơ sữa",
    "peanuts": "Đậu phộng (Hạt lạc), Bơ đậu phộng, Dầu lạc thô, Kẹo lạc, Bột đậu phộng",
    "seafood": "Tôm, Cua, Ghẹ, Mực, Cá biển, Cá nước ngọt, Nước mắm cốt cá, Bột nêm hải sản, Mắm tôm",
    "gluten": "Bột mì, Đạm lúa mì, Mì ăn liền, Bánh mì, Bánh quy, Mạch nha đại mạch, Yến mạch",
    "eggs": "Lòng trắng trứng, Lòng đỏ trứng, Bột trứng, Sốt trứng gà, Hoạt chất từ trứng (E1105)",
    "soy": "Đậu nành (Đỗ tương), Đậu phụ (Tàu hũ), Nước tương (Xì dầu), Sữa đậu nành, Chất nhũ hóa đậu nành (E322), Đạm đậu nành",
    "tree_nuts": "Hạt điều, Hạnh nhân, Hạt óc chó, Hạt dẻ cười, Hạt mắc ca, Hạt phỉ, Sữa hạt",
    "sesame": "Hạt mè (Hạt vừng), Dầu mè, Bơ mè (Sốt vừng nghiền), Bánh kẹo rắc mè",
    "curie:FOODON:00001006": "Thịt bò, Thịt heo (Thịt lợn), Thịt cừu, Thịt băm, Thịt đỏ, Xúc xích thịt, Thịt hộp, Giăm bông, Mỡ heo, Mỡ bò",
    "curie:FOODON:00001134": "Thịt bò tươi, Thịt bò băm, Bò viên, Nước cốt hầm bò, Chiết xuất thịt bò, Mỡ bò",
    "curie:FOODON:00001038": "Thịt heo (Thịt lợn), Xúc xích heo, Giăm bông, Thịt xông khói, Thịt hộp, Chà bông heo, Mỡ heo",
    "curie:FOODON:00001131": "Thịt gà, Ức gà, Thịt vịt, Gà tây, Nước cốt gà, Bột thịt gà, Xúc xích gà, Mỡ gà",
    "curie:FOODON:00001040": "Thịt gà, Ức gà, Nước cốt hầm gà, Bột chiết xuất thịt gà, Xúc xích gà",
    "curie:FOODON:00001092": "Thịt bò, Thịt heo, Thịt gà, Thịt vịt, Thịt cừu, Xúc xích thịt, Thịt hộp, Nước cốt hầm xương thịt",
}

ALLERGEN_RELATED_INGREDIENTS_EN = {
    "milk": "Milk powder, Fresh milk, Dairy whey protein, Casein, Lactose, Cheese, Cream, Yogurt, Dairy butter",
    "peanuts": "Peanuts, Peanut butter, Unrefined peanut oil, Peanut brittle, Peanut flour",
    "seafood": "Shrimp, Crab, Squid, Fish fillet, Fish sauce, Seafood extract seasoning, Shrimp paste",
    "gluten": "Wheat flour, Wheat gluten, Instant noodles, Bread, Cookies, Barley malt, Oats",
    "eggs": "Egg white (Albumin), Egg yolk, Egg powder, Mayonnaise, Egg lysozyme (E1105)",
    "soy": "Soybeans, Tofu, Soy sauce, Soy milk, Soy lecithin (E322), Isolated soy protein",
    "tree_nuts": "Cashew nuts, Almonds, Walnuts, Pistachios, Macadamia nuts, Hazelnuts, Nut milk",
    "sesame": "Sesame seeds, Sesame oil, Sesame butter (Tahini), Sesame crackers",
    "curie:FOODON:00001006": "Beef, Pork, Lamb, Ground meat, Red meat, Meat sausages, Luncheon meat, Ham, Bacon, Lard, Beef tallow",
    "curie:FOODON:00001134": "Beef cuts, Ground beef, Beef meatballs, Beef broth, Beef extract, Beef tallow",
    "curie:FOODON:00001038": "Pork meat, Pork sausage, Ham, Bacon, Luncheon meat, Pork floss, Pork lard",
    "curie:FOODON:00001131": "Chicken meat, Chicken breast, Duck meat, Turkey, Chicken broth, Chicken extract powder",
    "curie:FOODON:00001040": "Chicken meat, Chicken breast, Chicken stock, Chicken extract powder, Chicken sausage",
    "curie:FOODON:00001092": "Beef, Pork, Chicken, Duck, Lamb, Meat sausages, Canned meat, Meat broth and stock",
}

# Curated everyday foods that users commonly eat and experience allergic reactions from,
# mapped to their exact FoodOn CURIE and inferred FoodOn allergen family root.
EVERYDAY_ALLERGY_FOODS = [
    {
        "curie": "FOODON:03310351",
        "allergen_code": "milk",
        "emoji": "🧈",
        "food_name_vi": "Bơ (Bơ sữa động vật)",
        "food_name_en": "Butter (Dairy Butter)",
        "keywords": ["bơ", "bo", "bơ sữa", "bơ lạt", "bơ mặn", "butter", "dairy butter"],
    },
    {
        "curie": "FOODON:03000287",
        "allergen_code": "milk",
        "emoji": "🧀",
        "food_name_vi": "Phô mai (Pho mát)",
        "food_name_en": "Cheese",
        "keywords": ["phô mai", "pho mai", "pho mát", "pho mat", "cheese", "cheddar", "mozzarella"],
    },
    {
        "curie": "FOODON:00001014",
        "allergen_code": "milk",
        "emoji": "🥣",
        "food_name_vi": "Sữa chua",
        "food_name_en": "Yogurt",
        "keywords": ["sữa chua", "sua chua", "yaourt", "yogurt", "yoghurt"],
    },
    {
        "curie": "FOODON:00005747",
        "allergen_code": "milk",
        "emoji": "🍦",
        "food_name_vi": "Kem sữa / Váng sữa",
        "food_name_en": "Dairy Cream & Ice Cream",
        "keywords": ["kem", "kem sữa", "váng sữa", "vang sua", "whey", "cream", "ice cream", "whipping cream"],
    },
    {
        "curie": "FOODON:00001257",
        "allergen_code": "milk",
        "emoji": "🥛",
        "food_name_vi": "Sữa tươi / Sữa đặc / Sữa bột",
        "food_name_en": "Cow's Milk & Milk Powder",
        "keywords": ["sữa", "sua", "sữa tươi", "sữa bột", "sữa đặc", "sữa bò", "milk", "cow milk", "dairy"],
    },
    {
        "curie": "FOODON:00002351",
        "allergen_code": "gluten",
        "emoji": "🍞",
        "food_name_vi": "Bánh mì / Bánh ngọt",
        "food_name_en": "Wheat Bread & Pastries",
        "keywords": ["bánh mì", "banh mi", "bánh ngọt", "bánh quy", "bread", "toast", "pastry", "cookie"],
    },
    {
        "curie": "FOODON:03306944",
        "allergen_code": "gluten",
        "emoji": "🍜",
        "food_name_vi": "Mì ăn liền / Mì sợi / Nui",
        "food_name_en": "Wheat Noodles & Pasta",
        "keywords": ["mì", "mi", "mì tôm", "mì ăn liền", "mì sợi", "nui", "bột mì", "noodle", "pasta", "wheat"],
    },
    {
        "curie": "FOODON:03411237",
        "allergen_code": "seafood",
        "emoji": "🦐",
        "food_name_vi": "Tôm (Tôm sú, Tôm thẻ, Tép)",
        "food_name_en": "Shrimp & Prawns",
        "keywords": ["tôm", "tom", "tép", "mắm tôm", "shrimp", "prawn"],
    },
    {
        "curie": "FOODON:02021446",
        "allergen_code": "seafood",
        "emoji": "🦀",
        "food_name_vi": "Cua / Ghẹ biển",
        "food_name_en": "Crab & Crustaceans",
        "keywords": ["cua", "ghẹ", "ghe", "crab", "shellfish", "crustacean"],
    },
    {
        "curie": "FOODON:00001248",
        "allergen_code": "seafood",
        "emoji": "🐟",
        "food_name_vi": "Cá / Chả cá / Nước mắm",
        "food_name_en": "Fish & Fish Sauce",
        "keywords": ["cá", "ca", "chả cá", "nước mắm", "nuoc mam", "cá hồi", "cá ngừ", "fish", "fish sauce", "salmon", "tuna"],
    },
    {
        "curie": "FOODON:03412112",
        "allergen_code": "seafood",
        "emoji": "🦑",
        "food_name_vi": "Mực / Nghêu / Sò / Ốc / Hàu",
        "food_name_en": "Squid, Clams, Oysters & Molluscs",
        "keywords": ["mực", "muc", "nghêu", "ngao", "sò", "ốc", "hàu", "bạch tuộc", "squid", "clam", "oyster", "mollusc", "octopus"],
    },
    {
        "curie": "FOODON:03316061",
        "allergen_code": "eggs",
        "emoji": "🥚",
        "food_name_vi": "Trứng gà / Trứng vịt / Trứng cút",
        "food_name_en": "Chicken & Duck Eggs",
        "keywords": ["trứng", "trung", "trứng gà", "trứng vịt", "lòng đỏ", "lòng trắng", "egg", "eggs", "albumin"],
    },
    {
        "curie": "FOODON:03301440",
        "allergen_code": "eggs",
        "emoji": "🥗",
        "food_name_vi": "Sốt trứng gà (Sốt trộn salad)",
        "food_name_en": "Mayonnaise Sauce",
        "keywords": ["mayonnaise", "sốt mayonnaise", "sốt trứng", "sốt trứng gà", "mayo"],
    },
    {
        "curie": "FOODON:00004697",
        "allergen_code": "soy",
        "emoji": "🌱",
        "food_name_vi": "Đậu phụ (Tàu hũ) / Sữa đậu nành",
        "food_name_en": "Tofu & Soy Milk",
        "keywords": ["đậu phụ", "dau phu", "đậu hũ", "tàu hũ", "sữa đậu nành", "đậu nành", "đỗ tương", "tofu", "soy", "soybean", "soya"],
    },
    {
        "curie": "FOODON:03301415",
        "allergen_code": "soy",
        "emoji": "🍶",
        "food_name_vi": "Nước tương (Xì dầu) / Tương bần",
        "food_name_en": "Soy Sauce & Fermented Soy",
        "keywords": ["nước tương", "nuoc tuong", "xì dầu", "xi dau", "tương", "soy sauce"],
    },
    {
        "curie": "FOODON:00003206",
        "allergen_code": "peanuts",
        "emoji": "🥜",
        "food_name_vi": "Đậu phộng (Hạt lạc) / Bơ đậu phộng",
        "food_name_en": "Peanuts & Peanut Butter",
        "keywords": ["đậu phộng", "dau phong", "lạc", "lac", "hạt lạc", "bơ đậu phộng", "bơ lạc", "kẹo lạc", "peanut", "peanuts", "peanut butter", "groundnut"],
    },
    {
        "curie": "FOODON:00003615",
        "allergen_code": "tree_nuts",
        "emoji": "🌰",
        "food_name_vi": "Hạt điều / Hạnh nhân / Óc chó / Mắc ca",
        "food_name_en": "Cashew, Almond, Walnut & Macadamia",
        "keywords": ["hạt điều", "hat dieu", "hạnh nhân", "hanh nhan", "óc chó", "oc cho", "mắc ca", "hạt dẻ", "hạt phỉ", "cashew", "almond", "walnut", "pistachio", "macadamia", "hazelnut", "nut"],
    },
    {
        "curie": "FOODON:03310306",
        "allergen_code": "sesame",
        "emoji": "🌿",
        "food_name_vi": "Hạt mè (Hạt vừng) / Dầu mè",
        "food_name_en": "Sesame Seeds & Sesame Oil",
        "keywords": ["mè", "me", "vừng", "vung", "hạt mè", "hạt vừng", "dầu mè", "bơ mè", "sesame", "tahini"],
    },
]


