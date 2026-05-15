local speakFirstWordOnSpellcheckOpen = false
local function OnYapperLoaded()
    if not _G.YapperAPI then return end
    local lastWord = ""
    local voiceID = 0
    local suppressNextProofread = false
    local pendingTypo = nil
    local activeTypo = nil

    local function Speak(text)
        if not text or text == "" then return end
        if voiceID == 0 then
            local voices = C_VoiceChat.GetTtsVoices()
            voiceID = (voices and voices[1]) and voices[1].voiceID or 0
        end
        if voiceID ~= 0 then
            C_VoiceChat.SpeakText(voiceID, text, 1, 0, 100)
        end
    end

    YapperAPI:RegisterCallback("EDITBOX_TEXT_CHANGED", function(text, isUserInput, box)
        if not isUserInput or not box then return end
        
        -- Reset lastWord memory if the box is cleared so typing the same word
        -- in a new sentence still triggers speech.
        if not text or text == "" then
            lastWord = ""
            return
        end

        local pos = box:GetCursorPosition()
        local textBefore = text:sub(1, pos)
        if textBefore:sub(-1):match("[%s%p]") then
            if suppressNextProofread then
                suppressNextProofread = false
                return
            end
            local word = textBefore:match("(%S+)[%s%p]*$")
            if word then
                local clean = word:gsub("[%p%s]+$", "")
                if clean ~= "" and clean ~= lastWord then
                    lastWord = clean
                    Speak(clean)
                end
            end
        end
    end)

    YapperAPI:RegisterCallback("SPELLCHECK_SUGGESTION", function(typo)
        if typo ~= activeTypo then
            activeTypo = typo
            pendingTypo = "Typo: " .. typo .. ". Press up or down for suggestions. "
            speakFirstWordOnSpellcheckOpen = true
        end
    end)

    local suggTimer, lastSpokenHighlight = nil, ""
    YapperAPI:RegisterCallback("SPELLCHECK_SUGGESTION_HIGHLIGHTED", function(text, index, total)
        if suggTimer then suggTimer:Cancel() end
        
        suggTimer = C_Timer.NewTimer(0.3, function()
            local clean = text:gsub("^%d+%.%s*", "")
            if clean == lastSpokenHighlight then return end
            lastSpokenHighlight = clean
            
            C_VoiceChat.StopSpeakingText()
            
            if speakFirstWordOnSpellcheckOpen and pendingTypo then
                Speak(pendingTypo .. clean)
                speakFirstWordOnSpellcheckOpen = false
                pendingTypo = nil
            else
                Speak(clean)
            end
        end)
    end)

    YapperAPI:RegisterCallback("SPELLCHECK_APPLIED", function()
        suppressNextProofread = true
        activeTypo = nil
        lastWord = "" -- Also clear word memory on apply
    end)

    YapperAPI:RegisterCallback("EDITBOX_HIDE", function()
        C_VoiceChat.StopSpeakingText()
        activeTypo = nil
        speakFirstWordOnSpellcheckOpen = false
        lastWord = "" -- Clear memory when closing
    end)

    YapperAPI:RegisterCallback("ICON_GALLERY_SHOW", function(q)
        Speak("Icon gallery open" .. ((q and q ~= "") and (" searching " .. q) or ""))
    end)
    YapperAPI:RegisterCallback("ICON_GALLERY_HIDE", function() Speak("Icon gallery closed") end)
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function() C_Timer.After(1, OnYapperLoaded) end)
