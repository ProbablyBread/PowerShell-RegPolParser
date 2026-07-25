function ParseHeader([Array]$byteArray) {
    # read first 8 bytes of $byteArray (header) and ensure it is a .pol file
    # signature = 80 82 101 103, this must match exactly
    # file version = next 4 bytes, only perform basic sanity checks
    for ($i = 0; $i -lt 7; $i++) {
        switch ($i) {
            0 { # signature check
                if ($byteArray[$i] -ne 80) { return $false }
                break
            }
            1 {
                if ($byteArray[$i] -ne 82) { return $false }
                break
            }
            2 {
                if ($byteArray[$i] -ne 101) { return $false }
                break
            }
            3 {
                if ($byteArray[$i] -ne 103) { return $false }
                break
            } # signature check ends here
            4 { # version check
                if ($byteArray[$i] -lt 1) { return $false }
                break
            } 
            5 { 
                if ($byteArray[$i] -lt 0) { return $false }
                break
            }
            6 {
                if ($byteArray[$i] -lt 0) { return $false }
                break
            }
            7 {
                if ($byteArray[$i] -lt 0) { return $false }
                break
            } # version check ends here
        }
    }

    return $true
}

function ConvertTypeSlice([Array]$byteArray) {
    # only the first byte matters since it's always < 255
    switch ($byteArray[0]) {
        0 { return "REG_NONE" }
        1 { return "REG_SZ" }
        2 { return "REG_EXPAND_SZ" }
        3 { return "REG_BINARY" }
        4 { return "REG_DWORD" }              
        5 { return "REG_DWORD_BIG_ENDIAN" }
        6 { return "REG_LINK" }
        7 { return "REG_MULTI_SZ" }
        8 { return "REG_RESOURCE_LIST" }
        9 { return "REG_FULL_RESOURCE_DESCRIPTOR" }
        10 { return "REG_RESOURCE_REQUIREMENTS_LIST" }
        11 { return "REG_QWORD" } 
    }
}

function ConvertToLong([Array]$byteArray) {
    [long]$num = 0

    for ($i = 0; $i -lt $byteArray.Length; $i++) {
        $num += $byteArray[$i] * [Math]::Pow(256, $i)
    }

    return $num
}

function BEConvertToLong([Array]$byteArray) {
    [Array]$rev = @()

    for ($i = $byteArray.Length - 1; $i -ge 0; $i--) {
        $rev += $byteArray[$i]
    }

    return ConvertToLong $rev
}

function ConvertString([Array]$byteArray) {
    [string]$string = $null

    foreach ($b in $byteArray) {
        # skip null bytes
        if ($b -gt 0) {
            $string += [char][byte]$b  
        }
    }

    return $string
}

function ConvertMultiString([Array]$byteArray) {
    [string]$string = $null

    for ($i = 0; $i -lt $byteArray.Length; ) {
        # read until null terminator
        while (-not($byteArray[$i] -eq 0 -and $byteArray[$i + 1] -eq 0)) {
            $string += [char][byte]$byteArray[$i] # add only first byte, discard second null byte
            $i += 2 # increment by 2
        }

        $i += 2 # skip null terminator

        # end of MULTI_SZ is another null terminator
        # if it's not the end of the MULTI_SZ, add a comma instead
        if (-not($byteArray[$i] -eq 0 -and $byteArray[$i + 1] -eq 0)) {
            $string += "," # separate strings by commas
        }
        else {
            return $string
        }
    }
}

function ConvertBinary([Array]$byteArray) {
    [string]$string = "hex:"
    
    foreach ($b in $byteArray) {
        $string += [byte]$b.ToString("X") # convert to hex
    }

    return $string
}

function ParseRegPol([string]$file) {
    if ($PSVersionTable.PSVersion.Major -eq 5) {
        $byteArray = Get-Content -Raw -Encoding Byte -Path "$file" -ErrorAction Stop
    }
    elseif ($PSVersionTable.PSVersion.Major -ge 6) {
        $byteArray = Get-Content -Raw -AsByteStream -Path "$file" -ErrorAction Stop
    }
    else {
        Write-Host "Unsupported PowerShell version."
        return 1
    }

    $lines = @()

    if ($byteArray.Length -eq 0) {
        Write-Host "Invalid .pol file supplied."
        return 1
    }

    if (-not ($(ParseHeader $byteArray))) {
        Write-Host "Invalid .pol file supplied."
        return 1
    }

    # read two bytes at once, skipping the header
    for ($i = 8; $i -lt $byteArray.Length - 1; ) {
        $keySlice = @()
        $valueSlice = @()
        $typeSlice = @()
        $sizeSlice = @()
        $dataSlice = @()
        
        # slice key (from 91 00 ([) to 00 00 - null terminated string)
        if ($byteArray[$i] -eq 91 -and $byteArray[$i + 1] -eq 0) {
            $i += 2 # read from next 2 bytes

            # look for null terminator
            while (-not($byteArray[$i] -eq 0 -and $byteArray[$i + 1] -eq 0)) {
                $keySlice += $byteArray[$i]
                $keySlice += $byteArray[$i + 1]
                $i += 2
            }

            $i += 2 # increment by 2 to skip null bytes
            $keyString = ConvertString $keySlice
        }
        else {
            Write-Host "Invalid .pol file supplied."
            return 1
        }

        # slice value (check two bytes for ;) and read to next 00 00 - null terminated string)
        if ($byteArray[$i] -eq 59 -and $byteArray[$i + 1] -eq 0) {
            $i += 2 # read from next 2 bytes

            # look for null terminator
            while (-not($byteArray[$i] -eq 0 -and $byteArray[$i + 1] -eq 0)) {
                $valueSlice += $byteArray[$i]
                $valueSlice += $byteArray[$i + 1]
                $i += 2
            }

            $i += 2 # increment by 2 to skip null bytes
            $valueString = ConvertString $valueSlice
        }
        else {
            Write-Host "Invalid .pol file supplied."
            return 1
        }

        # slice 4 bytes for type (check two bytes for ;)
        if ($byteArray[$i] -eq 59 -and $byteArray[$i + 1] -eq 0) {
            $i += 2 # read from next 2 bytes

            # read 4 bytes
            for ($j = 0; $j -lt 4; $j++) {
                $typeSlice += $byteArray[$i + $j]
            }

            $i += 4 # skip 4 bytes read
            $typeString = ConvertTypeSlice $typeSlice
        }
        else {
            Write-Host "Invalid .pol file supplied."
            return 1
        }

        # slice 4 bytes for size (check two bytes for ;)
        if ($byteArray[$i] -eq 59 -and $byteArray[$i + 1] -eq 0) {
            $i += 2 # read from next 2 bytes

            # read 4 bytes
            for ($j = 0; $j -lt 4; $j++) {
                $sizeSlice += $byteArray[$i + $j]
            }
            
            $i += 4 # skip 4 bytes read
            $size = ConvertToLong $sizeSlice
        }
        else {
            Write-Host "Invalid .pol file supplied."
            return 1
        }

        # read size bytes (check two bytes for ;)
        if ($byteArray[$i] -eq 59 -and $byteArray[$i + 1] -eq 0) {
            $i += 2 # read from next 2 bytes

            # consume size bytes
            for ($j = 0; $j -lt $size; $j++) {
                $dataSlice += $byteArray[$i + $j]
            }

            $i += $size # skip size bytes read

            if ($typeString -eq "REG_DWORD" -or $typeString -eq "REG_QWORD") {
                $dataString = ConvertToLong $dataSlice
            }
            elseif ($typeString -eq "REG_DWORD_BIG_ENDIAN" -or $typeString -eq "REG_QWORD_BIG_ENDIAN") {
                $dataString = BEConvertToLong $dataSlice
            }
            elseif ($typeString -eq "REG_SZ" -or $typeString -eq "REG_EXPAND_SZ" -or $typeString -eq "REG_LINK") {
                $dataString = ConvertString $dataSlice
            }
            elseif ($typeString -eq "REG_MULTI_SZ") {
                $dataString = ConvertMultiString $dataSlice
            }
            elseif ($typeString -eq "REG_BINARY") {
                $dataString = ConvertBinary $dataSlice
            }
            # don't handle REG_NONE and resource types
            else {
                $dataString = $null
            }
        }
        else {
            Write-Host "Invalid .pol file supplied."
            return 1
        }

        # read next two bytes to check for closing 93 00 (])
        if ($byteArray[$i] -eq 93 -and $byteArray[$i + 1] -eq 0) {
            $i += 2 # skip those two bytes and loop again
            $lines += "[$keyString;$valueString;$typeString;$size;$dataString]"
        }
        else {
            Write-Host "Invalid .pol file supplied."
            return 1
        }
    }

    return $lines
}
