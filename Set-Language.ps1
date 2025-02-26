<#
    .SYNOPSIS
    Sets and activates the specified language for a user on a Windows machine.

    .DESCRIPTION
    This script is used to set and activate the specified language for a user on a Windows machine. 
    It is necessary because the base Windows image does not include the required language packs.

    .NOTES
#> 

try {
    # Set the Windows display language to English (Australia)
    Set-WinUILanguageOverride -Language 'en-AU'
    Set-WinUserLanguageList -LanguageList 'en-AU' -Force
    Set-Culture -CultureInfo 'en-AU'
    Set-WinHomeLocation -GeoId 12

    Write-Output "Language settings successfully applied."
} catch {
    Write-Output "An error occurred while setting the language: $_"
    exit 1
}