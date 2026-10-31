import urllib.request
import urllib.error
import base64
import json
import os
import struct

os.makedirs('d:/NutriViet/docs/requirements/assets', exist_ok=True)

# Diagram 1 definition
wf1 = """flowchart TD
    Start([Start]) --> Scan[Select Scanner]
    Scan --> Perm{Camera Permission?}

    Perm -- No --> ReqPerm[Request Permission]
    ReqPerm --> PermGranted{Granted?}
    PermGranted -- No --> ManualFallback[Permission Error] --> EndScan([End])
    PermGranted -- Yes --> Cam[Capture Food Label]
    Perm -- Yes --> Cam

    Cam --> QualityCheck{Image Readable?}
    QualityCheck -- No --> Retake[Retake Tips] --> Cam
    QualityCheck -- Yes --> OCR[Run On-Device OCR]

    OCR --> OCROk{Text Extracted?}
    OCROk -- No --> RetryPrompt{Retry?}
    RetryPrompt -- Yes --> Cam
    RetryPrompt -- No --> ManualEntry[Manual Entry] --> Match
    OCROk -- Yes --> Match[Normalize & Match DB]

    Match --> CheckRules[Check Allergen & FoodOn Rules]
    CheckRules --> ProfileCheck[Cross-Ref Health Profile]
    ProfileCheck --> RiskCalc{Risk Level?}

    RiskCalc -- High --> Red["RED: Danger / Allergen"]
    RiskCalc -- Caution --> Yellow["YELLOW: Caution"]
    RiskCalc -- Safe --> Green["GREEN: Safe"]

    Red --> SaveHistory[Save to History]
    Yellow --> SaveHistory
    Green --> SaveHistory

    SaveHistory --> DetailsPrompt{View Details?}
    DetailsPrompt -- Yes --> ViewDetails[Ingredient Details] --> Done([End])
    DetailsPrompt -- No --> Done
"""

# Diagram 2 definition
wf2 = """flowchart TD
    Start([Start]) --> Sub[Submit Product Info & Photos]
    Sub --> Validate{Fields Complete?}
    Validate -- No --> Error[Validation Errors] --> Sub
    Validate -- Yes --> Staging[Create PENDING Record]

    Staging --> DupCheck{Duplicate?}
    DupCheck -- Yes --> FlagDup[Flag Duplicate] --> AdminQueue
    DupCheck -- No --> AutoCheck{Format Checks Pass?}
    AutoCheck -- No --> FlagData[Flag Invalid Data] --> AdminQueue
    AutoCheck -- Yes --> ReadyQueue[Mark Ready] --> AdminQueue[Admin Queue]

    AdminQueue --> Review[Admin Reviews Product]
    Review --> Decision{Data Accurate?}

    Decision -- Needs Fix --> CanFix{Contributor Can Fix?}
    CanFix -- Yes --> RequestInfo[Request Corrections]
    RequestInfo --> ReSubmit[Contributor Resubmits] --> Staging
    CanFix -- No --> Reject[Reject & Notify] --> EndAudit([End])

    Decision -- Approved --> Approve[Approve to Catalog]
    Approve --> UpdateDB[Update DB & Log Audit]
    UpdateDB --> Live[Go Live & Notify User] --> Done([End])
"""

def generate():
    diagrams = [
        ('workflow_diagram_1.png', wf1),
        ('workflow_diagram_2.png', wf2)
    ]

    for filename, code in diagrams:
        payload = json.dumps({'code': code})
        b64 = base64.urlsafe_b64encode(payload.encode('utf-8')).decode('ascii')
        url = f'https://mermaid.ink/img/{b64}?type=png&bgColor=white'
        req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
        out_file = os.path.join('d:/NutriViet/docs/requirements/assets', filename)
        print(f"Fetching {filename}...")
        try:
            with urllib.request.urlopen(req, timeout=20) as resp:
                data = resp.read()
                with open(out_file, 'wb') as f:
                    f.write(data)
                w, h = struct.unpack('>II', data[16:24])
            print(f"Successfully saved {out_file} ({len(data)} bytes, {w}x{h} px)")
        except urllib.error.HTTPError as e:
            print(f"Error {e.code} {e.reason}: {e.read().decode('utf-8', errors='ignore')}")

if __name__ == '__main__':
    generate()
