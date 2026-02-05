#Requires -Version 7.0

BeforeAll {
	$script:dscModuleName = 'TemplateModule'

	Import-Module -Name $script:dscModuleName
}

AfterAll {
	Get-Module -Name $script:dscModuleName -All | Remove-Module -Force
}

Describe 'Write-Log' -Tag 'Unit' {

	BeforeEach {
		InModuleScope -ModuleName $dscModuleName {
			# Set up a test log file path
			$script:testLogPath = Join-Path $env:TEMP "test_log_$(Get-Date -Format 'yyyyMMddHHmmss').log"
			$script:LogFile = $script:testLogPath
			$Global:LogFile = $script:testLogPath
		}
	}

	AfterEach {
		InModuleScope -ModuleName $dscModuleName {
			# Clean up test log file
			if (Test-Path $script:testLogPath) {
				Remove-Item $script:testLogPath -Force -ErrorAction SilentlyContinue
			}
		}
	}

	Context 'When logging simple messages' {
		It 'Should create log file on first write' {
			InModuleScope -ModuleName $dscModuleName {
				Write-Log -Message 'Test message' -Level INFO -NoConsole

				Test-Path $script:testLogPath | Should -Be $true
			}
		}

		It 'Should write message to log file' {
			InModuleScope -ModuleName $dscModuleName {
				Write-Log -Message 'Test message' -Level INFO -NoConsole

				$content = Get-Content $script:testLogPath -Raw
				$content | Should -Match 'Test message'
			}
		}

		It 'Should include timestamp in log entry' {
			InModuleScope -ModuleName $dscModuleName {
				Write-Log -Message 'Test' -Level INFO -NoConsole

				$content = Get-Content $script:testLogPath -Raw
				$content | Should -Match '\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}'
			}
		}

		It 'Should include log level in entry' {
			InModuleScope -ModuleName $dscModuleName {
				Write-Log -Message 'Test' -Level ERROR -NoConsole

				$content = Get-Content $script:testLogPath -Raw
				$content | Should -Match '\[ERROR\]'
			}
		}
	}

	Context 'When using different log levels' {
		It 'Should log INFO messages' {
			InModuleScope -ModuleName $dscModuleName {
				Write-Log -Message 'Info message' -Level INFO -NoConsole

				$content = Get-Content $script:testLogPath -Raw
				$content | Should -Match '\[INFO\].*Info message'
			}
		}

		It 'Should log DEBUG messages' {
			InModuleScope -ModuleName $dscModuleName {
				Write-Log -Message 'Debug message' -Level DEBUG -NoConsole

				$content = Get-Content $script:testLogPath -Raw
				$content | Should -Match '\[DEBUG\].*Debug message'
			}
		}

		It 'Should log WARN messages' {
			InModuleScope -ModuleName $dscModuleName {
				Write-Log -Message 'Warning message' -Level WARN -NoConsole

				$content = Get-Content $script:testLogPath -Raw
				$content | Should -Match '\[WARN\].*Warning message'
			}
		}

		It 'Should log ERROR messages' {
			InModuleScope -ModuleName $dscModuleName {
				Write-Log -Message 'Error message' -Level ERROR -NoConsole

				$content = Get-Content $script:testLogPath -Raw
				$content | Should -Match '\[ERROR\].*Error message'
			}
		}

		It 'Should log SUCCESS messages' {
			InModuleScope -ModuleName $dscModuleName {
				Write-Log -Message 'Success message' -Level SUCCESS -NoConsole

				$content = Get-Content $script:testLogPath -Raw
				$content | Should -Match '\[SUCCESS\].*Success message'
			}
		}
	}

	Context 'When redacting sensitive information' {
		It 'Should redact password in key=value format' {
			InModuleScope -ModuleName $dscModuleName {
				Write-Log -Message 'password=secret123' -Level INFO -NoConsole

				$content = Get-Content $script:testLogPath -Raw
				$content | Should -Match 'password=\*\*\*REDACTED\*\*\*'
				$content | Should -Not -Match 'secret123'
			}
		}

		It 'Should redact token in key=value format' {
			InModuleScope -ModuleName $dscModuleName {
				Write-Log -Message 'token=abc123xyz' -Level INFO -NoConsole

				$content = Get-Content $script:testLogPath -Raw
				$content | Should -Match 'token=\*\*\*REDACTED\*\*\*'
				$content | Should -Not -Match 'abc123xyz'
			}
		}

		It 'Should redact API key in JSON format' {
			InModuleScope -ModuleName $dscModuleName {
				Write-Log -Message '{"apikey": "secret123"}' -Level INFO -NoConsole

				$content = Get-Content $script:testLogPath -Raw
				$content | Should -Match 'apikey": "\*\*\*REDACTED\*\*\*'
				$content | Should -Not -Match 'secret123'
			}
		}

		It 'Should be case insensitive when redacting' {
			InModuleScope -ModuleName $dscModuleName {
				Write-Log -Message 'PASSWORD=secret' -Level INFO -NoConsole

				$content = Get-Content $script:testLogPath -Raw
				$content | Should -Match 'PASSWORD=\*\*\*REDACTED\*\*\*'
			}
		}
	}

	Context 'When appending multiple messages' {
		It 'Should append messages to existing log' {
			InModuleScope -ModuleName $dscModuleName {
				Write-Log -Message 'First message' -Level INFO -NoConsole
				Write-Log -Message 'Second message' -Level INFO -NoConsole

				$content = Get-Content $script:testLogPath -Raw
				$content | Should -Match 'First message'
				$content | Should -Match 'Second message'
			}
		}

		It 'Should preserve message order' {
			InModuleScope -ModuleName $dscModuleName {
				Write-Log -Message 'Message 1' -Level INFO -NoConsole
				Write-Log -Message 'Message 2' -Level INFO -NoConsole
				Write-Log -Message 'Message 3' -Level INFO -NoConsole

				$lines = Get-Content $script:testLogPath
				$lines[0] | Should -Match 'Message 1'
				$lines[1] | Should -Match 'Message 2'
				$lines[2] | Should -Match 'Message 3'
			}
		}
	}

	Context 'When using PassThru parameter' {
		It 'Should return true on successful write' {
			InModuleScope -ModuleName $dscModuleName {
				$result = Write-Log -Message 'Test' -Level INFO -NoConsole -PassThru

				$result | Should -Be $true
			}
		}
	}

	Context 'When using positional parameters' {
		It 'Should accept message as first positional parameter' {
			InModuleScope -ModuleName $dscModuleName {
				Write-Log 'Positional message' -NoConsole

				$content = Get-Content $script:testLogPath -Raw
				$content | Should -Match 'Positional message'
			}
		}

		It 'Should accept level as second positional parameter' {
			InModuleScope -ModuleName $dscModuleName {
				Write-Log 'Test message' ERROR -NoConsole

				$content = Get-Content $script:testLogPath -Raw
				$content | Should -Match '\[ERROR\]'
			}
		}
	}
}
