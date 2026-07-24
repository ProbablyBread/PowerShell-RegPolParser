function ParseHeader([Array]$byteArray) {
    # read first 8 bytes of $byteArray (header) and ensure it is a .pol file
    # header should be 80 82 101 103 01 00 00 00
    for ($i = 0; $i -lt 9; $i++) {
        switch ($i) {
            0 {
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
            }
            4 {
                if ($byteArray[$i] -ne 1) { return $false }
                break
            }
            5 {
                if ($byteArray[$i] -ne 0) { return $false }
                break
            }
            6 {
                if ($byteArray[$i] -ne 0) { return $false }
                break
            }
            7 {
                if ($byteArray[$i] -ne 0) { return $false }
                break
            }
        }
    }

    return $true
}

function TypeToString([Array]$byteArray) {
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

function ByteArrayToInt([Array]$byteArray) {
    [long]$num = 0

    for ($i = 0; $i -lt $byteArray.Length; $i++) {
        $num += $byteArray[$i] * [Math]::Pow(256, $i)
    }

    return $num
}

function BEByteArrayToInt([Array]$byteArray) {
    [Array]$rev = @()

    for ($i = $byteArray.Length - 1; $i -ge 0; $i--) {
        $rev += $byteArray[$i]
    }

    return ByteArrayToInt $rev
}

function ByteArrayToString([Array]$byteArray) {
    [string]$string = $null

    foreach ($b in $byteArray) {
        # skip null bytes
        if ($b -gt 0) {
            $string += [char][byte]$b  
        }
    }

    return $string
}

function ParseRegPol([string]$file) {
    $byteArray = Get-Content -Raw -Encoding Byte -Path "$file"
    $lines = @()

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
            $keyString = ByteArrayToString $keySlice
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
            $valueString = ByteArrayToString $valueSlice
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
            $typeString = TypeToString $typeSlice
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
            $size = ByteArrayToInt $sizeSlice
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
                $dataString = ByteArrayToInt $dataSlice
            }
            elseif ($typeString -eq "REG_DWORD_BIG_ENDIAN") {
                $dataString = BEByteArrayToInt $dataSlice
            }
            else {
                $dataString = ByteArrayToString $dataSlice
            }
        }
        else {
            Write-Host "Invalid .pol file supplied."
            return 1
        }

        # read next two bytes to check for closing 93 00 (])
        if ($byteArray[$i] -eq 93 -and $byteArray[$i + 1] -eq 0) {
            $i += 2 # skip those two bytes and loop again
        }
        else {
            Write-Host "Invalid .pol file supplied."
            return 1
        }

        $lines += "[$keyString;$valueString;$typeString;$size;$dataString]"
    }

    return $lines
}
