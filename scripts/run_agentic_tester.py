import argparse
import subprocess
import json
import os
import time
import requests

def get_hierarchy():
    print("Scansione della UI in corso...")
    try:
        result = subprocess.run(["maestro", "hierarchy"], capture_output=True, text=True, check=True)
        return result.stdout
    except subprocess.CalledProcessError as e:
        print(f"Errore durante l'estrazione della hierarchy: {e}")
        return None

def call_llm(hierarchy, goal):
    prompt = f"""
    Sei un Agente IA di test QA autonomo per app mobile.
    Il tuo obiettivo corrente è: {goal}
    
    Questa è la View Hierarchy attuale della schermata (testo JSON/XML):
    {hierarchy}
    
    Decidi la tua prossima mossa. Rispondi RIGOROSAMENTE con un JSON formattato così:
    {{
        "action": "tap" | "input" | "scroll" | "success" | "failure",
        "id": "Testo o ID dell'elemento da toccare (se action è tap o input)",
        "text": "Testo da scrivere (se action è input)",
        "reason": "Spiega brevemente la tua mossa"
    }}
    """
    
    headers = {
        "Content-Type": "application/json"
    }
    
    payload = {
        "model": "llama3.2",
        "messages": [{"role": "user", "content": prompt}],
        "response_format": {"type": "json_object"}
    }
    
    print("🧠 Invocazione dell'LLM Locale (Ollama)...")
    try:
        # Usa l'endpoint di Ollama compatibile con lo standard OpenAI
        response = requests.post("http://localhost:11434/v1/chat/completions", headers=headers, json=payload)
        response.raise_for_status()
        data = response.json()
        return json.loads(data["choices"][0]["message"]["content"])
    except Exception as e:
        print(f"❌ Errore nella chiamata a Ollama locale: {e}")
        return None

def execute_action(action):
    act = action.get("action")
    el_id = action.get("id")
    
    if act == "tap":
        subprocess.run(["maestro", "tap", el_id])
    elif act == "input":
        text = action.get("text")
        subprocess.run(["maestro", "tap", el_id])
        subprocess.run(["maestro", "inputText", text])
    elif act == "scroll":
        subprocess.run(["maestro", "scroll"])

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--platform', required=True)
    parser.add_argument('--app', required=True)
    parser.add_argument('--goal', required=True)
    args = parser.parse_args()

    print(f"🤖 Inizio Test Agentico per {args.app} su {args.platform} [100% LOCALE]")
    print(f"🎯 Obiettivo: {args.goal}")
    
    max_steps = 15
    for step in range(max_steps):
        print(f"\n--- 🔄 Step {step + 1}/{max_steps} ---")
        
        hierarchy = get_hierarchy()
        if not hierarchy:
            print("❌ Impossibile leggere lo schermo.")
            exit(1)
            
        action = call_llm(hierarchy, args.goal)
        if not action:
            exit(1)
            
        print(f"🧠 Decisione IA: {action.get('reason')} -> {action.get('action').upper()}")
        
        act = action.get("action")
        if act == "success":
            print("✅ Obiettivo Raggiunto con Successo!")
            return
        elif act == "failure":
            print("❌ L'IA ha stabilito che l'obiettivo non può essere raggiunto.")
            exit(1)
            
        execute_action(action)
        time.sleep(3) # Pausa per l'animazione della UI
        
    print("❌ Raggiunto il limite massimo di mosse (Loop Infinito). Test Fallito.")
    exit(1)

if __name__ == "__main__":
    main()
