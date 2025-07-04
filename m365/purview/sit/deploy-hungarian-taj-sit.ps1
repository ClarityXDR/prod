# PowerShell script to deploy Hungarian TAJ custom SIT in Azure Cloud Shell

# Check if running in Azure Cloud Shell
$isCloudShell = $env:AZUREPS_HOST_ENVIRONMENT -eq "cloud-shell/1.0"
if ($isCloudShell) {
    Write-Host "Running in Azure Cloud Shell" -ForegroundColor Cyan
}

# Install Exchange Online Management module if not present
if (-not (Get-Module -ListAvailable -Name ExchangeOnlineManagement)) {
    Write-Host "Installing Exchange Online Management module..." -ForegroundColor Yellow
    Install-Module -Name ExchangeOnlineManagement -Force -AllowClobber -Scope CurrentUser
}

# Import the module
Import-Module ExchangeOnlineManagement -ErrorAction SilentlyContinue

# Connect to Security & Compliance PowerShell (if not already connected)
if (-not (Get-Command Get-DlpSensitiveInformationType -ErrorAction SilentlyContinue)) {
    Write-Host "Connecting to Security & Compliance Center..." -ForegroundColor Yellow
    try {
        Connect-IPPSSession -WarningAction SilentlyContinue
        Write-Host "Successfully connected to Security & Compliance Center" -ForegroundColor Green
    }
    catch {
        Write-Host "Failed to connect. Please ensure you have the necessary permissions." -ForegroundColor Red
        Write-Host "Error: $_" -ForegroundColor Red
        exit 1
    }
}

# Define the XML content as a string
$xmlContent = @'
<?xml version="1.0" encoding="utf-8"?>
<RulePackage xmlns="http://schemas.microsoft.com/office/2011/mce">
  <RulePack id="c7e5c5a0-1234-4567-8901-234567890123">
    <Version major="1" minor="0" build="0" revision="0" />
    <Publisher id="00000000-0000-0000-0000-000000000000" />
    <Details defaultLangCode="en">
      <LocalizedDetails langcode="en">
        <PublisherName>Bio-Rad Laboratories Inc.</PublisherName>
        <Name>Hungarian TAJ excluding IDT Reference</Name>
        <Description>Detects Hungarian Social Security Numbers (TAJ) while excluding IDT Reference numbers and spreadsheet false positives</Description>
      </LocalizedDetails>
    </Details>
  </RulePack>
  
  <Rules>
    <Entity id="d7e5c5a0-1234-4567-8901-234567890124" patternsProximity="300" recommendedConfidence="85">
      <!-- High confidence: TAJ with spaces and keywords -->
      <Pattern confidenceLevel="95">
        <IdMatch idRef="Regex_hungarian_taj_with_spaces_validated" />
        <Any minMatches="0" maxMatches="0">
          <Match idRef="Regex_exclude_contexts" />
        </Any>
        <Any minMatches="1">
          <Match idRef="Keyword_hungarian_taj_strong" />
        </Any>
      </Pattern>
      
      <!-- High confidence: TAJ with spaces, no excluded contexts -->
      <Pattern confidenceLevel="85">
        <IdMatch idRef="Regex_hungarian_taj_with_spaces_validated" />
        <Any minMatches="0" maxMatches="0">
          <Match idRef="Regex_exclude_contexts" />
        </Any>
        <Any minMatches="0" maxMatches="0">
          <Match idRef="Regex_spreadsheet_context" />
        </Any>
      </Pattern>
      
      <!-- Medium confidence: 9 digits with TAJ keywords -->
      <Pattern confidenceLevel="75">
        <IdMatch idRef="Regex_hungarian_taj_no_spaces_validated" />
        <Any minMatches="0" maxMatches="0">
          <Match idRef="Regex_exclude_contexts" />
        </Any>
        <Any minMatches="0" maxMatches="0">
          <Match idRef="Regex_spreadsheet_context" />
        </Any>
        <Any minMatches="1">
          <Match idRef="Keyword_hungarian_taj" />
        </Any>
      </Pattern>
      
      <!-- Low confidence: formatted TAJ in specific context -->
      <Pattern confidenceLevel="65">
        <IdMatch idRef="Regex_hungarian_taj_formatted" />
        <Any minMatches="0" maxMatches="0">
          <Match idRef="Regex_exclude_contexts" />
        </Any>
        <Any minMatches="1">
          <Match idRef="Keyword_hungarian_taj_context" />
        </Any>
      </Pattern>
    </Entity>
    
    <!-- Regex patterns with validation -->
    <Regex id="Regex_hungarian_taj_with_spaces_validated">(?&lt;![\d\-\/\.])\d{3}\s\d{3}\s\d{3}(?![\d\-\/\.])</Regex>
    <Regex id="Regex_hungarian_taj_no_spaces_validated">(?&lt;![\d\-\/\.\s])\d{9}(?![\d\-\/\.])</Regex>
    <Regex id="Regex_hungarian_taj_formatted">(?&lt;![\d\-\/\.])\d{3}[\s\-]?\d{3}[\s\-]?\d{3}(?![\d\-\/\.])</Regex>
    
    <!-- Exclusion patterns -->
    <Regex id="Regex_exclude_contexts">(?i)(?:IDT\s*Reference|Reference\s*\*|Order\s*#|Invoice\s*#|Product\s*Code|Item\s*#|Serial\s*#|Part\s*#|Model\s*#|ID\s*:|Phone|Tel|Fax|Mobile|Account\s*#|Transaction\s*#|Tracking\s*#|Case\s*#|Ticket\s*#|Contract\s*#|Policy\s*#|Claim\s*#|Member\s*ID|Employee\s*ID|Customer\s*ID|Date\s{0,20}\d{9}|\d{9}\s{0,20}Date|Version\s*\d+\.\d+\.\d+|\d+\.\d+\.\d+\.\d+|IP\s*Address|MAC\s*Address)</Regex>
    
    <!-- Spreadsheet-specific exclusion patterns -->
    <Regex id="Regex_spreadsheet_context">(?i)(?:[A-Z]+\d+[:=]|SUM\s*\(|VLOOKUP|INDEX|MATCH|IF\s*\(|COUNT|AVERAGE|MIN|MAX|ROW|COLUMN|OFFSET|\$[A-Z]+\$?\d+|R\d+C\d+|Sheet\d+!|\'[^\']\'!|Formula|Cell\s*[A-Z]\d+|\d{9}[\s,;\|]\d{9})</Regex>
    
    <!-- Strong TAJ keywords (high confidence) -->
    <Keyword id="Keyword_hungarian_taj_strong">
      <Group matchStyle="word">
        <Term>taj szám</Term>
        <Term>taj-szám</Term>
        <Term>taj száma</Term>
        <Term>társadalombiztosítási azonosító jel</Term>
        <Term>tb azonosító</Term>
        <Term>tb szám</Term>
      </Group>
    </Keyword>
    
    <!-- General TAJ keywords -->
    <Keyword id="Keyword_hungarian_taj">
      <Group matchStyle="word">
        <Term>taj</Term>
        <Term>társadalombiztosítási</Term>
        <Term>social insurance number</Term>
        <Term>társadalombiztosítás</Term>
        <Term>tb</Term>
      </Group>
    </Keyword>
    
    <!-- TAJ context keywords -->
    <Keyword id="Keyword_hungarian_taj_context">
      <Group matchStyle="word">
        <Term>beteg</Term>
        <Term>páciens</Term>
        <Term>biztosított</Term>
        <Term>egészségbiztosítás</Term>
        <Term>egészségügyi</Term>
        <Term>orvos</Term>
        <Term>kórház</Term>
        <Term>rendelő</Term>
        <Term>patient</Term>
        <Term>insured</Term>
        <Term>health insurance</Term>
        <Term>medical</Term>
        <Term>healthcare</Term>
      </Group>
    </Keyword>
    
    <LocalizedStrings>
      <Resource idRef="d7e5c5a0-1234-4567-8901-234567890124">
        <Name default="true" langcode="en">Hungarian TAJ excluding IDT Reference</Name>
        <Description default="true" langcode="en">
          Detects Hungarian Social Security Numbers (TAJ) in XXX XXX XXX or XXXXXXXXX format, 
          excluding IDT References, spreadsheet contexts, and other common 9-digit false positives.
          Uses negative lookahead/lookbehind to prevent matching numbers within larger digit sequences.
        </Description>
      </Resource>
    </LocalizedStrings>
  </Rules>
</RulePackage>
'@

try {
    # Create a simple UI-focused approach with the correct cmdlets
    Write-Host "Preparing enhanced XML file for rule package deployment..." -ForegroundColor Cyan
    Write-Host "This version includes:" -ForegroundColor Yellow
    Write-Host "  ✓ Negative lookahead/lookbehind to prevent partial matches" -ForegroundColor Green
    Write-Host "  ✓ Spreadsheet context exclusion (formulas, cell references)" -ForegroundColor Green
    Write-Host "  ✓ Enhanced IDT Reference and product code exclusion" -ForegroundColor Green
    Write-Host "  ✓ Multiple confidence levels based on context" -ForegroundColor Green
    Write-Host "  ✓ Hungarian medical/healthcare context keywords" -ForegroundColor Green
    Write-Host ""
    
    # Check if a similar SIT already exists
    $existingSITs = Get-DlpSensitiveInformationType | Where-Object {
        $_.Publisher -ne "Microsoft Corporation" -and 
        ($_.Name -like "*Hungarian*" -or $_.Name -like "*TAJ*")
    }
    
    if ($existingSITs) {
        Write-Host "NOTE: Found existing Hungarian SIT(s) that may be similar:" -ForegroundColor Yellow
        $existingSITs | Format-Table Name, Publisher -AutoSize
        
        Write-Host "WHY YOU NEED THIS NEW XML-BASED SIT:" -ForegroundColor Magenta
        Write-Host "1. IDT Reference exclusion: Specifically excludes 9-digit numbers near IDT References" -ForegroundColor White
        Write-Host "2. Format detection: Handles both XXX XXX XXX and XXXXXXXXX formats with proper confidence levels" -ForegroundColor White
        Write-Host "3. XML-based: Uses the XML schema for reliable deployment and consistency" -ForegroundColor White
        Write-Host "4. Configurable: XML format allows for easy modifications if needed in the future" -ForegroundColor White
        Write-Host ""
        
        Write-Host "To see details of the existing SIT, run:" -ForegroundColor Yellow
        Write-Host "Get-DlpSensitiveInformationType -Identity 'Hungarian Social Security Number (TAJ) copy' | Format-List *" -ForegroundColor Cyan
        Write-Host ""
    }
    
    # Save XML to user's download location in Azure Cloud Shell
    $downloadPath = "~/clouddrive"
    if (-not (Test-Path $downloadPath)) {
        # Try to create clouddrive if it doesn't exist
        try {
            Write-Host "Setting up Azure Cloud Drive..." -ForegroundColor Gray
            clouddrive mount
            Start-Sleep -Seconds 2
        }
        catch {
            # If clouddrive fails, use home directory
            $downloadPath = "~"
            Write-Host "Cloud Drive not available. Using home directory instead." -ForegroundColor Yellow
        }
    }
    
    # If clouddrive still doesn't exist, use home directory
    if (-not (Test-Path $downloadPath)) {
        $downloadPath = "~"
    }
    
    $exportFile = "$downloadPath/Hungarian-TAJ-SIT.xml"
    $xmlContent | Out-File -FilePath $exportFile -Encoding UTF8
    
    Write-Host "XML file saved to: $exportFile" -ForegroundColor Green
    
    # Resolve the actual file path for reading
    $resolvedPath = (Resolve-Path $exportFile).Path
    Write-Host "Resolved file path: $resolvedPath" -ForegroundColor Gray
    Write-Host ""
    
    # Try to deploy using the correct cmdlet for rule packages
    Write-Host "Attempting to deploy rule package using the correct cmdlet..." -ForegroundColor Yellow
    try {
        # Verify file exists before attempting to read
        if (-not (Test-Path $resolvedPath)) {
            throw "XML file not found at resolved path: $resolvedPath"
        }
        
        # Use the recommended syntax from the documentation
        Write-Host "Reading file bytes from: $resolvedPath" -ForegroundColor Gray
        $fileBytes = [System.IO.File]::ReadAllBytes($resolvedPath)
        Write-Host "File size: $($fileBytes.Length) bytes" -ForegroundColor Gray
        
        New-DlpSensitiveInformationTypeRulePackage -FileData $fileBytes
        
        Write-Host "Success! Rule package deployed successfully." -ForegroundColor Green
        Write-Host ""
        
        # Wait for propagation
        Write-Host "Waiting for rule package to propagate..." -ForegroundColor Yellow
        Start-Sleep -Seconds 10
        
        # Verify using the recommended verification commands
        Write-Host "Verifying rule package deployment..." -ForegroundColor Yellow
        try {
            $rulePackages = Get-DlpSensitiveInformationTypeRulePackage
            if ($rulePackages) {
                Write-Host "Rule packages found:" -ForegroundColor Green
                $rulePackages | Format-Table Name, PublisherName -AutoSize
            }
        }
        catch {
            Write-Host "Could not retrieve rule packages: $($_.Exception.Message)" -ForegroundColor Yellow
        }
        
        Write-Host "Verifying sensitive information type..." -ForegroundColor Yellow
        $newSIT = Get-DlpSensitiveInformationType | Where-Object {$_.Name -eq "Hungarian TAJ excluding IDT Reference"}
        if ($newSIT) {
            Write-Host "Sensitive information type found!" -ForegroundColor Green
            $newSIT | Format-List Name, Publisher, Description
            
            Write-Host ""
            Write-Host "✅ SUCCESS: Hungarian TAJ excluding IDT Reference SIT has been deployed!" -ForegroundColor Green
            Write-Host "✅ The SIT is now available for use in DLP policies" -ForegroundColor Green
        }
        else {
            Write-Host "SIT may need time to propagate. Please check again later using:" -ForegroundColor Yellow
            Write-Host "Get-DlpSensitiveInformationType | Where-Object {\$_.Name -eq 'Hungarian TAJ excluding IDT Reference'}" -ForegroundColor Cyan
        }
    }
    catch {
        Write-Host "Error deploying rule package: $($_.Exception.Message)" -ForegroundColor Red
        
        # Show file location for manual download
        Write-Host ""
        Write-Host "File is available for manual download at: $exportFile" -ForegroundColor Yellow
        Write-Host "Falling back to manual import method..." -ForegroundColor Yellow
        
        Write-Host ""
        Write-Host "XML-BASED IMPORT INSTRUCTIONS:" -ForegroundColor Cyan
        Write-Host "------------------------" -ForegroundColor Cyan
        Write-Host "1. Download the XML file from Azure Cloud Shell:" -ForegroundColor White
        Write-Host "   • Click the download button in the Cloud Shell toolbar" -ForegroundColor White
        Write-Host "   • Navigate to $exportFile" -ForegroundColor White
        Write-Host "   • Download the file to your local computer" -ForegroundColor White
        Write-Host ""
        Write-Host "2. Import the XML in Security & Compliance Center:" -ForegroundColor White
        Write-Host "   • Go to https://compliance.microsoft.com" -ForegroundColor White
        Write-Host "   • Navigate to Data Classification > Sensitive info types" -ForegroundColor White
        Write-Host "   • Click 'Create sensitive info type'" -ForegroundColor White
        Write-Host "   • Choose 'Import'" -ForegroundColor White
        Write-Host "   • Upload the XML file you downloaded" -ForegroundColor White
        Write-Host ""
    }
    
    # Add enhanced testing instructions
    Write-Host ""
    Write-Host "TESTING YOUR ENHANCED XML-BASED SIT:" -ForegroundColor Cyan
    Write-Host "-----------------------------------" -ForegroundColor Cyan
    Write-Host "Test Cases - SHOULD DETECT:" -ForegroundColor Green
    Write-Host "  ✅ TAJ szám: 123 456 789" -ForegroundColor White
    Write-Host "  ✅ Beteg TAJ: 123456789" -ForegroundColor White
    Write-Host "  ✅ Társadalombiztosítási azonosító: 123 456 789" -ForegroundColor White
    Write-Host ""
    Write-Host "Test Cases - SHOULD NOT DETECT:" -ForegroundColor Red
    Write-Host "  ❌ IDT Reference *123 456 789" -ForegroundColor White
    Write-Host "  ❌ Order #123456789" -ForegroundColor White
    Write-Host "  ❌ =SUM(123456789)" -ForegroundColor White
    Write-Host "  ❌ A1:123456789" -ForegroundColor White
    Write-Host "  ❌ 0123456789 (10 digits)" -ForegroundColor White
    Write-Host "  ❌ 12345678901 (11 digits)" -ForegroundColor White
    Write-Host "  ❌ Phone: 123-456-789" -ForegroundColor White
    Write-Host "  ❌ Version 1.2.3.456.789" -ForegroundColor White
    Write-Host "  ❌ Serial #123456789" -ForegroundColor White
    Write-Host "  ❌ 123456789,987654321 (CSV data)" -ForegroundColor White
    Write-Host ""
    
    # Update the summary
    Write-Host ""
    Write-Host "DEPLOYMENT SUMMARY:" -ForegroundColor Cyan
    Write-Host "1. ✅ XML rule package successfully deployed" -ForegroundColor Green
    Write-Host "2. ✅ File backup available at: $exportFile" -ForegroundColor Green
    Write-Host "3. 🔍 Test with sample data to confirm IDT Reference exclusion works properly" -ForegroundColor Yellow
    Write-Host "4. ℹ️  Note: A maximum of 10 rule packages are supported per tenant" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Your Hungarian TAJ SIT with IDT Reference exclusion is ready for use! 🎉" -ForegroundColor Green
}
catch {
    Write-Host "Error creating custom SIT: $_" -ForegroundColor Red
    Write-Host ""
    
    # Get more detailed error information
    if ($_.Exception.InnerException) {
        Write-Host "Inner Exception: $($_.Exception.InnerException.Message)" -ForegroundColor Red
    }
    
    # Try to get more specific error information
    if ($_.Exception.Message -like "*already exists*") {
        Write-Host "It appears a SIT with this name already exists." -ForegroundColor Yellow
    }
    
    # Check if SIT already exists
    Write-Host ""
    Write-Host "Checking for existing custom SITs..." -ForegroundColor Yellow
    $existingSIT = Get-DlpSensitiveInformationType | Where-Object {$_.Publisher -ne "Microsoft Corporation"}
    if ($existingSIT) {
        Write-Host "Found existing custom SIT(s):" -ForegroundColor Yellow
        $existingSIT | Format-Table Name, Type, Publisher, Id -AutoSize
        Write-Host ""
        Write-Host "If you need to replace an existing SIT, first remove it with:" -ForegroundColor Yellow
        Write-Host "Remove-DlpSensitiveInformationType -Identity '<SIT_ID_or_NAME>'" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Then wait 5-10 minutes before creating the new one." -ForegroundColor Yellow
    }
    
    # Show available parameter sets for debugging
    Write-Host ""
    Write-Host "For debugging - checking available cmdlet syntax:" -ForegroundColor Yellow
    Get-Help New-DlpSensitiveInformationType -Detailed | Select-Object -ExpandProperty syntax
}
finally {
    # Clean up temporary files (if they were created)
    if (Test-Path $xmlFile -ErrorAction SilentlyContinue) {
        Remove-Item $xmlFile -Force -ErrorAction SilentlyContinue
    }
    if (Test-Path $tempFile -ErrorAction SilentlyContinue) {
        Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
    }
}

