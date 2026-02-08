#Requires -Version 7.0

BeforeAll {
    $script:dscModuleName = 'TemplateModule'

    Import-Module -Name $script:dscModuleName
}

AfterAll {
    Get-Module -Name $script:dscModuleName -All | Remove-Module -Force
}

Describe 'Write-ToLog' -Tag 'Unit' {

    Context 'When using INFO level' {
        It 'Should write to Verbose stream' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Write-Verbose

                Write-ToLog -Message 'Info message' -Level INFO

                Should -Invoke Write-Verbose -Times 1 -Exactly -ParameterFilter {
                    $Message -eq 'Info message'
                }
            }
        }
    }

    Context 'When using DEBUG level' {
        It 'Should write to Verbose stream' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Write-Verbose

                Write-ToLog -Message 'Debug message' -Level DEBUG

                Should -Invoke Write-Verbose -Times 1 -Exactly -ParameterFilter {
                    $Message -eq 'Debug message'
                }
            }
        }
    }

    Context 'When using WARN level' {
        It 'Should write to Warning stream' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Write-Warning

                Write-ToLog -Message 'Warning message' -Level WARN

                Should -Invoke Write-Warning -Times 1 -Exactly -ParameterFilter {
                    $Message -eq 'Warning message'
                }
            }
        }
    }

    Context 'When using ERROR level' {
        It 'Should write to Error stream' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Write-Error

                Write-ToLog -Message 'Error message' -Level ERROR

                Should -Invoke Write-Error -Times 1 -Exactly -ParameterFilter {
                    $Message -eq 'Error message'
                }
            }
        }
    }

    Context 'When using SUCCESS level' {
        It 'Should write to Information stream' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Write-Information

                Write-ToLog -Message 'Success message' -Level SUCCESS

                Should -Invoke Write-Information -Times 1 -Exactly -ParameterFilter {
                    $MessageData -eq 'Success message'
                }
            }
        }
    }

    Context 'When using LogPath parameter' {
        It 'Should write timestamped entry to file' {
            InModuleScope -ModuleName $script:dscModuleName {
                $logFile = Join-Path $TestDrive 'test.log'
                Mock Write-Verbose

                Write-ToLog -Message 'File entry' -Level INFO -LogPath $logFile

                Test-Path -LiteralPath $logFile | Should -BeTrue
                $content = Get-Content -LiteralPath $logFile -Raw
                $content | Should -Match '\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\] \[INFO\] File entry'
            }
        }

        It 'Should append multiple entries' {
            InModuleScope -ModuleName $script:dscModuleName {
                $logFile = Join-Path $TestDrive 'append.log'
                Mock Write-Verbose
                Mock Write-Warning

                Write-ToLog -Message 'First' -Level INFO -LogPath $logFile
                Write-ToLog -Message 'Second' -Level WARN -LogPath $logFile

                $lines = Get-Content -LiteralPath $logFile
                $lines | Should -HaveCount 2
                $lines[0] | Should -Match '\[INFO\] First'
                $lines[1] | Should -Match '\[WARN\] Second'
            }
        }
    }

    Context 'When using positional parameters' {
        It 'Should accept message as first positional parameter' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Write-Verbose

                Write-ToLog 'Positional message'

                Should -Invoke Write-Verbose -Times 1 -Exactly -ParameterFilter {
                    $Message -eq 'Positional message'
                }
            }
        }

        It 'Should accept level as second positional parameter' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Write-Warning

                Write-ToLog 'Test message' WARN

                Should -Invoke Write-Warning -Times 1 -Exactly
            }
        }
    }

    Context 'When using default level' {
        It 'Should default to INFO level' {
            InModuleScope -ModuleName $script:dscModuleName {
                Mock Write-Verbose

                Write-ToLog -Message 'Default level'

                Should -Invoke Write-Verbose -Times 1 -Exactly
            }
        }
    }

    Context 'When validating parameters' {
        It 'Should throw on null message' {
            InModuleScope -ModuleName $script:dscModuleName {
                { Write-ToLog -Message $null } | Should -Throw
            }
        }

        It 'Should throw on empty message' {
            InModuleScope -ModuleName $script:dscModuleName {
                { Write-ToLog -Message '' } | Should -Throw
            }
        }

        It 'Should throw on invalid level' {
            InModuleScope -ModuleName $script:dscModuleName {
                { Write-ToLog -Message 'Test' -Level 'INVALID' } | Should -Throw
            }
        }
    }
}
