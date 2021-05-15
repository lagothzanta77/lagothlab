@echo off
msiexec /i c:\mytools\WindowsAdminCenter2103.msi /qn /L*v c:\mytools\admcenterlog.txt SME_PORT=6571 SSL_CERTIFICATE_OPTION=generate
