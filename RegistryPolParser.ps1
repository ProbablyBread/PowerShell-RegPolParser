function ReturnData($byteArr, $type) {
    # compute actual decimal data if DWORD/QWORD
    if ($type -eq "REG_DWORD" -or $type -eq "REG_QWORD") {
        $data = 0
        for ($i = 0; $i -lt $byteArr.Length; $i++) {
            $data = $data -bor ([int]$byteArr[$i] -shl (8 * $i))
        }
    }
    elseif ($type -eq "REG_DWORD_BIG_ENDIAN") {
        $data = 0
        $length = $byteArr.Length
        for ($i = 0; $i -lt $length; $i++) {
            $data = $data -bor ([int]$byteArr[$length - 1 - $i] -shl (8 * $i))
        }
    }
    # otherwise return a string
    else {
        $data = ReturnStringFromBytes $byteArr
    }

    return $data
}

function ReturnSize($byteArr) {
    for ($i = 0; $i -lt $length; $i++) {
        $size = $size -bor ([int]$byteArr[$i] -shl (8 * $i))
    }

    return $size
}

function ReturnRegType($byteArr) {
    foreach ($i in $byteArr) {
        $int += $i
    }

    switch ($int) {
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

function ReturnStringFromBytes($part) {    
    # unicode control codes to ignore
    $ctrlCodes = 0..31 
    $ctrlCodes += 127..159
    [string]$str = $null

    foreach ($c in $part) {
        if ($c -notin $ctrlCodes) {
            $str += [char][byte]$c
        }
    }

    return $str
}

function ParseEntry($part) {
    $counter = 0 # tracks the part currently extracted (key;value;type;size;data)
    $byteArray = @() 
    $type = $null
    
    [string]$str = $null
    
    for ($i = 0; $i -lt $part.Length; $i++) {
        if ($part[$i] -ne 59 -or $part[$i + 1] -ne 0) {
            $byteArray += $part[$i]
        }
        else {
            $counter++
            
            switch ($counter) {
                # key
                1 {
                    $str += ReturnStringFromBytes $byteArray
                    $str += ";"
                }

                # value
                2 {
                    $str += ReturnStringFromBytes $byteArray
                    $str += ";"
                }

                # type
                3 {
                    $type = ReturnRegType($byteArray)
                    $str += $type 
                    $str += ";"
                }

                # size
                4 {
                    $str += ReturnSize($byteArray)
                    $str += ";"
                }
            }

            $byteArray = @()
        }
    }

    # data
    $str += ReturnData $byteArray $type
    return $str
}

function ParseRegPol([string]$file) {
    $reg = Get-Content -Raw $file -Encoding Byte

    $startPos = 0 # store $reg start index
    $endPos = 0 # store $reg end index

    $lines = @() # array of lines extracted

    # start from index 8 (ignore first 8 header bytes)
    # 59 = ;
    # 91 = [
    # 93 = ]
    for ($i = 8; $i -lt $reg.Length; $i++) {
        if ($reg[$i] -eq 91 -and $reg[$i + 1] -eq 0) {
            $startPos = $i
        }
        elseif ($reg[$i] -eq 93 -and $reg[$i + 1] -eq 0) {
            $endPos = $i
            $lines += ParseEntry $reg[$($startPos + 1)..$($endPos - 1)] # pass slice without [ and ]
        }
    }

    return $lines
}
