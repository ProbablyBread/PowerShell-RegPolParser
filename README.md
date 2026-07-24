# PowerShell-RegPolParser
Bunch of functions to parse registry.pol files from Group Policies into human readable formats. Returns an array of strings in the format of \[Key;Value;Type;Size;Data\]. 

## References
- [Registry Policy File Format (learn.microsoft.com)](https://learn.microsoft.com/en-us/previous-versions/windows/desktop/policy/registry-policy-file-format)
- [Corrections to Microsoft documentation about the Registry Policy (registry.pol) File Format (aaron-margosis.medium.com)](https://aaron-margosis.medium.com/corrections-to-microsoft-documentation-about-the-registry-policy-file-format-f6cb0caa9a80)
- [Registry value types (learn.microsoft.com)]([url](https://learn.microsoft.com/en-us/windows/win32/sysinfo/registry-value-types))

## Usage
```powershell
$entries = @()
$entries = ParseRegPol "/path/to/registry.pol"
```
