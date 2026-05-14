local function OnYapperLoaded()
    if not _G.YapperAPI then return end
    local lastWord, voices = "", C_VoiceChat.GetTtsVoices()
    local voiceID = (voices and voices[1]) and voices[1].voiceID or 0
    local suppressNextProofread = false
    local function Speak(text)
        if text and text ~= "" then C_VoiceChat.SpeakText(voiceID, text, 1, 0, 100) end
    end
    YapperAPI:RegisterCallback("EDITBOX_TEXT_CHANGED", function(text, isUserInput, box)
        if not isUserInput or not text or not box then return end
        local pos = box:GetCursorPosition()
        local textBefore = text:sub(1, pos)
        if textBefore:sub(-1):match("[%s%p]") then
            if suppressNextProofread then suppressNextProofread = false return end
            local word = textBefore:match("(%S+)[%s%p]*$")
            if word then
                local clean = word:gsub("[%p%s]+$", "")
                if clean ~= "" and clean ~= lastWord then lastWord = clean Speak(clean) end
            end
        end
    end)
    YapperAPI:RegisterCallback("SPELLCHECK_SUGGESTION", function(typo)
        Speak("Typo: " .. typo .. ". Press up or down for suggestions.")
    end)
    local suggTimer, lastSpokenHighlight = nil, ""
    YapperAPI:RegisterCallback("SPELLCHECK_SUGGESTION_HIGHLIGHTED", function(text, index, total)
        if suggTimer then suggTimer:Cancel() end
        suggTimer = C_Timer.NewTimer(0.3, function()
            local clean = text:gsub("^%d+%.%s*", "")
            if clean == lastSpokenHighlight then return end
            lastSpokenHighlight = clean
            C_VoiceChat.StopSpeakingText()
            Speak(clean .. ". Option " .. index .. " of " .. total)
        end)
    end)
    YapperAPI:RegisterCallback("SPELLCHECK_APPLIED", function() suppressNextProofread = true end)
    YapperAPI:RegisterCallback("EDITBOX_HIDE", function() C_VoiceChat.StopSpeakingText() end)
    YapperAPI:RegisterCallback("ICON_GALLERY_SHOW", function(q)
        Speak("Icon gallery open" .. ((q and q ~= "") and (" searching " .. q) or ""))
    end)
    YapperAPI:RegisterCallback("ICON_GALLERY_HIDE", function() Speak("Icon gallery closed") end)
end
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function() C_Timer.After(1, OnYapperLoaded) end)
