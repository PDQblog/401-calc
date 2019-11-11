$FormatNumbers = {
    $this.Text -match '[0-9]'
    $this.Text = $this.Text -replace '[a-z]', ""
}
$AddCommas = {
    $this.Text = '{0:N0}' -f [int]$this.text
}
$CalculatePercentage = {
    if ([int]$this.Text -lt 1) {
        $this.Text = "{0:P1}" -f ([decimal]$this.Text)
    }
    elseif ([int]$this.Text -ge 1) {
        $this.Text = "{0:P1}" -f ([decimal]$this.Text / 100)
    }

}
$RemovePercentage = {
    $this.Text = $this.Text.Replace("%", "")
}

function New-RetirementGraph {
    param(
        [PSCustomObject]
        $Results
    )

    $table = @()
    $Year = (Get-Date).Year
    $AllYears = ([int]$Results.StartYear + 1)..$Results.EndYear
    foreach ($Age in $AllYears) {
        $EmployeeContributions = [int]$Results.Salary * [decimal]$Results.EmployeeContributionPercentage
        if (($EmployeeContributions -gt 19000) -and ($Age -lt 50)) {
            $EmployeeContributions = 19000
        }
        elseif (($EmployeeContributions -gt 25000) -and ($Age -ge 50)) {
            $EmployeeContributions = 25000
        }
        if ($Results.EmployeeContributionPercentage -lt $Results.CompanyMaxContributionPercentage) {
            $CompanyContributions = $EmployeeContributions * $Results.CompanyContributionPercentage
        }
        Else {
            $CompanyContributions = [int]$Results.Salary * [decimal]$Results.CompanyMaxContributionPercentage * [Decimal]$Results.CompanyContributionPercentage
        }
        $Contributions = $EmployeeContributions + $CompanyContributions
        $zRate = [math]::pow((1 + $Results.InterestRate / $Results.NumContributionsPerYear), ($Results.NumContributionsPerYear))
        $Results.Principal = [math]::Round(([int]$Results.Principal * $zRate) + ($Contributions * ($zRate - 1) / $Results.InterestRate))
        $YearlyResults = @{
            Year                = $Year
            Age                 = $Age
            Salary              = $Results.Salary
            "401kBalance"       = $Results.Principal
            AnnualContribution  = $EmployeeContributions
            CompanyContribution = $CompanyContributions
        }
        $table += $YearlyResults
        $Year = $Year + 1
        $Results.Salary = [int]$Results.Salary * (1 + $Results.AnnualIncrease)
    }
    [void][Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms.DataVisualization")

    $chart1 = New-object System.Windows.Forms.DataVisualization.Charting.Chart
    $chart1.Width = 1800    
    $chart1.BackColor = [System.Drawing.Color]::WhiteSmoke

    # title 
    [void]$chart1.Titles.Add("Your Ending Balance is $($Results.Principal.ToString('N0'))")
    $chart1.Titles[0].Font = [System.Drawing.Font]::new("Arial", 12, [System.Drawing.FontStyle]::Bold)

    # legend 
    $legend = New-Object system.Windows.Forms.DataVisualization.Charting.Legend
    $legend.name = "Legend1"
    $chart1.Legends.Add($legend)

    $chartarea = New-Object System.Windows.Forms.DataVisualization.Charting.ChartArea
    $chartarea.Name = "ChartArea1"
    $chartarea.AxisY.Title = "Balance"
    $chartarea.AxisX.Title = "Year"
    $chart1.ChartAreas.Add($chartarea)
    [void]$chart1.series.Add('balance')
    foreach ($datapoint in $table) {
        $x = $datapoint."Year"
        $y = $datapoint."401kBalance"
        [void]$chart1.Series["balance"].Points.addxy($x, $y)
    }

    # data series
    $chart1.Series["balance"].ChartType = [System.Windows.Forms.DataVisualization.Charting.SeriesChartType]::Line
    $chart1.Series["balance"].IsVisibleInLegend = $true
    $chart1.Series["balance"].BorderWidth = 3
    $chart1.Series["balance"].chartarea = "ChartArea1"
    $chart1.Series["balance"].Legend = "Legend1"
    $chart1.Series["balance"].color = "Blue"

    #Create Array to fill out sheet
    $FinalTable = @()
    foreach ($datapoint in $table) {
        $FinalTable += $datapoint | Select-Object @{Label = "Year"; Expression = { $_.Year } }, @{Label = "Age"; Expression = { $_.Age } }, 
        @{Label = "Your Contribution"; Expression = { $_.AnnualContribution.ToString('N0') } }, @{Label = "Employer Contribution"; Expression = { $_.CompanyContribution.ToString('N0') } },
        @{Label = "Balance"; Expression = { $_."401kBalance".ToString('N0') } }
    }


    $FundGraph = New-Object Windows.Forms.Form
    $FundGraph.WindowState = "Maximized"
    $FundGraph.StartPosition = "Manual" 
    $FundGraph.Location = New-Object System.Drawing.Size(0, 0)
    $FundGraph.Text = "MoneyMoneyMoney....MONEY!" 
    $FundGraph.AutoSize = $true
    $FundSheet = New-Object System.Windows.Forms.DataGridView
    $FundSheet.AutoSize = $true
    $FundSheet.AutoSizeColumnsMode = "AllCells"
    $FundSheet.BorderStyle = [System.Windows.Forms.BorderStyle]::None
    $FundSheet.DefaultCellStyle.BackColor = "#f4f4f4"
    $FundSheet.BackgroundColor = $FundSheet.DefaultCellStyle.BackColor
    $FundSheet.Location = New-Object System.Drawing.Point(0, 300)
    $FundSheet.DataSource = [System.Collections.arraylist]$FinalTable
    $FundGraph.controls.AddRange(@($FundSheet, $chart1))
    $FundGraph.Refresh()
    $FundGraph.Add_Shown( { $FundGraph.Activate() }) 
    $FundGraph.ShowDialog()
}

Function New-RetirementData {
    $showGraphClicked = { 
        "I was here" | out-file c:\temp\log.txt
        # Just return the object instead of doing a variable assignment and returning the variable
        $hash = [PSCustomObject]@{
            StartYear                        = $StartYear.Text
            EndYear                          = $EndYear.Text
            Principal                        = [int]$Principal.Text.Replace(",", "")
            Salary                           = [int]$Salary.Text.Replace(",", "")
            EmployeeContributionPercentage   = [decimal]$EmployeeContributionPercentage.Text.Replace("%", "") / 100
            CompanyContributionPercentage    = [decimal]$CompanyContributionPercentage.Text.Replace("%", "") / 100
            CompanyMaxContributionPercentage = [decimal]$CompanyMaxContributionPercentage.Text.Replace("%", "") / 100
            AnnualIncrease                   = [decimal]$AnnualIncrease.Text.Replace("%", "") / 100
            InterestRate                     = [decimal]$InterestRate.Text.Replace("%", "") / 100
            NumContributionsPerYear          = $NumContributionsPerYear.Text
            FormCompleted                    = $true
        }
        New-RetirementGraph $hash
    }

    ###Create Form for input
    Add-Type -AssemblyName System.Windows.Forms

    $RetirementCalculator = New-Object system.Windows.Forms.Form
    $RetirementCalculator.ClientSize = '300,310'
    $RetirementCalculator.text = "Muh Monies"
    $RetirementCalculator.TopMost = $false

    ###Create all the boxes
    ######Create OK and Cancel Button
    $OKButton = New-Object System.Windows.Forms.Button
    $OKButton.Location = New-Object System.Drawing.Point(75, 280)
    $OKButton.Size = New-Object System.Drawing.Size(75, 23)
    $OKButton.Text = 'Show Graph'
    # Don't set a DialogResult to prevent the form from closing
    # $OKButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $OKButton.Add_Click($showGraphClicked)
    $RetirementCalculator.AcceptButton = $OKButton

    $CancelButton = New-Object System.Windows.Forms.Button
    $CancelButton.Location = New-Object System.Drawing.Point(150, 280)
    $CancelButton.Size = New-Object System.Drawing.Size(75, 23)
    $CancelButton.Text = 'Cancel'
    $CancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $RetirementCalculator.CancelButton = $CancelButton

    ######Create Current Age Box 
    $StartYearLabel = New-Object system.Windows.Forms.Label
    $StartYearLabel.text = "Current Age"
    $StartYearLabel.AutoSize = $true
    $StartYearLabel.width = 25
    $StartYearLabel.height = 10
    $StartYearLabel.location = New-Object System.Drawing.Point(10, 10)
    
    $StartYear = New-Object system.Windows.Forms.TextBox
    $StartYear.width = 50
    $StartYear.height = 20
    $StartYear.add_TextChanged($FormatNumbers)
    $StartYear.MaxLength = 2
    $StartYear.location = New-Object System.Drawing.Point(190, 5)

    ######Create Current Age Box 
    $EndYearLabel = New-Object system.Windows.Forms.Label
    $EndYearLabel.text = "Retirement Age"
    $EndYearLabel.AutoSize = $true
    $EndYearLabel.width = 25
    $EndYearLabel.height = 10
    $EndYearLabel.location = New-Object System.Drawing.Point(10, 32)

    $EndYear = New-Object system.Windows.Forms.TextBox
    $EndYear.width = 50
    $EndYear.height = 20
    $EndYear.add_TextChanged($FormatNumbers)
    $EndYear.MaxLength = 3
    $EndYear.location = New-Object System.Drawing.Point(190, 27)

    ######Create Principal Box    
    $PrincipalLabel = New-Object system.Windows.Forms.Label
    $PrincipalLabel.text = "Current 401K Balance"
    $PrincipalLabel.AutoSize = $true
    $PrincipalLabel.width = 25
    $PrincipalLabel.height = 10
    $PrincipalLabel.location = New-Object System.Drawing.Point(10, 54)
    $Principal = New-Object system.Windows.Forms.TextBox

    $Principal.width = 50
    $Principal.height = 20
    $Principal.add_TextChanged( { $FormatNumbers })
    $Principal.add_LostFocus($AddCommas)
    $Principal.location = New-Object System.Drawing.Point(190, 49)

    ######Create Salary Box
    $SalaryLabel = New-Object System.Windows.Forms.Label
    $SalaryLabel.text = "Current Salary"
    $SalaryLabel.AutoSize = $true
    $SalaryLabel.width = 25
    $SalaryLabel.height = 10
    $SalaryLabel.location = New-Object System.Drawing.Point(10, 76)

    $Salary = New-Object System.Windows.Forms.TextBox
    $Salary.width = 50
    $Salary.height = 20
    $Salary.add_TextChanged($FormatNumbers)
    $Salary.add_LostFocus($AddCommas)
    $Salary.location = New-Object System.Drawing.Point(190, 71)

    ######Create Employee Contribution Percentage Box
    $EmployeeContributionPercentageLabel = New-Object system.Windows.Forms.Label
    $EmployeeContributionPercentageLabel.text = "401k Contribution %"
    $EmployeeContributionPercentageLabel.AutoSize = $true
    $EmployeeContributionPercentageLabel.width = 25
    $EmployeeContributionPercentageLabel.height = 10
    $EmployeeContributionPercentageLabel.location = New-Object System.Drawing.Point(10, 98)

    $EmployeeContributionPercentage = New-Object system.Windows.Forms.TextBox
    $EmployeeContributionPercentage.width = 50
    $EmployeeContributionPercentage.height = 20
    $EmployeeContributionPercentage.add_LostFocus($CalculatePercentage)
    $EmployeeContributionPercentage.add_TextChanged($FormatNumbers)
    $EmployeeContributionPercentage.add_GotFocus($RemovePercentage)
    $EmployeeContributionPercentage.location = New-Object System.Drawing.Point(190, 93)

    ######Create Employee Contribution Percentage Box
    $CompanyContributionPercentageLabel = New-Object system.Windows.Forms.Label
    $CompanyContributionPercentageLabel.text = "Employer Match%"
    $CompanyContributionPercentageLabel.AutoSize = $true
    $CompanyContributionPercentageLabel.width = 25
    $CompanyContributionPercentageLabel.height = 10
    $CompanyContributionPercentageLabel.location = New-Object System.Drawing.Point(10, 120)

    $CompanyContributionPercentage = New-Object system.Windows.Forms.TextBox
    $CompanyContributionPercentage.width = 50
    $CompanyContributionPercentage.height = 20
    $CompanyContributionPercentage.Text = "50.0%"
    $CompanyContributionPercentage.add_LostFocus($CalculatePercentage)
    $CompanyContributionPercentage.add_TextChanged($FormatNumbers)
    $CompanyContributionPercentage.add_GotFocus($RemovePercentage)
    $CompanyContributionPercentage.location = New-Object System.Drawing.Point(190, 115)

    ######Create Employee Contribution Max Percentage Box
    $CompanyMaxContributionPercentageLabel = New-Object system.Windows.Forms.Label
    $CompanyMaxContributionPercentageLabel.text = "Employer Max Match(% of Salary)"
    $CompanyMaxContributionPercentageLabel.AutoSize = $true
    $CompanyMaxContributionPercentageLabel.width = 25
    $CompanyMaxContributionPercentageLabel.height = 10
    $CompanyMaxContributionPercentageLabel.location = New-Object System.Drawing.Point(10, 142)

    $CompanyMaxContributionPercentage = New-Object system.Windows.Forms.TextBox
    $CompanyMaxContributionPercentage.width = 50
    $CompanyMaxContributionPercentage.height = 20
    $CompanyMaxContributionPercentage.add_LostFocus($CalculatePercentage)
    $CompanyMaxContributionPercentage.add_TextChanged($FormatNumbers)
    $CompanyMaxContributionPercentage.add_GotFocus($RemovePercentage)
    $CompanyMaxContributionPercentage.location = New-Object System.Drawing.Point(190, 137)

    ######Create Annual Salary Increase Box
    $AnnualIncreaseLabel = New-Object system.Windows.Forms.Label
    $AnnualIncreaseLabel.text = "Annual Salary Increase %"
    $AnnualIncreaseLabel.AutoSize = $true
    $AnnualIncreaseLabel.width = 25
    $AnnualIncreaseLabel.height = 10
    $AnnualIncreaseLabel.location = New-Object System.Drawing.Point(10, 164)

    $AnnualIncrease = New-Object system.Windows.Forms.TextBox
    $AnnualIncrease.width = 50
    $AnnualIncrease.height = 20
    $AnnualIncrease.add_LostFocus($CalculatePercentage)
    $AnnualIncrease.add_TextChanged($FormatNumbers)
    $AnnualIncrease.add_GotFocus($RemovePercentage)
    $AnnualIncrease.location = New-Object System.Drawing.Point(190, 159)

    ######Create Interest Rate Box
    $InterestRateLabel = New-Object system.Windows.Forms.Label
    $InterestRateLabel.text = "Average Rate of Return"
    $InterestRateLabel.AutoSize = $true
    $InterestRateLabel.width = 25
    $InterestRateLabel.height = 10
    $InterestRateLabel.location = New-Object System.Drawing.Point(10, 186)

    $InterestRate = New-Object system.Windows.Forms.TextBox
    $InterestRate.width = 50
    $InterestRate.height = 20
    $InterestRate.add_LostFocus($CalculatePercentage)
    $InterestRate.add_TextChanged($FormatNumbers)
    $InterestRate.add_GotFocus($RemovePercentage)
    $InterestRate.location = New-Object System.Drawing.Point(190, 181)

    ######Create Number of Contributions per year Box
    $NumContributionsPerYearLabel = New-Object system.Windows.Forms.Label
    $NumContributionsPerYearLabel.text = "Contributions Per Year"
    $NumContributionsPerYearLabel.AutoSize = $true
    $NumContributionsPerYearLabel.width = 25
    $NumContributionsPerYearLabel.height = 10
    $NumContributionsPerYearLabel.location = New-Object System.Drawing.Point(10, 208)

    $NumContributionsPerYear = New-Object system.Windows.Forms.TextBox
    $NumContributionsPerYear.multiline = $false
    $NumContributionsPerYear.text = "12"
    $NumContributionsPerYear.width = 50
    $NumContributionsPerYear.height = 20
    $NumContributionsPerYear.add_TextChanged($FormatNumbers)
    $NumContributionsPerYear.location = New-Object System.Drawing.Point(190, 205)

    ######Build final form
    $RetirementCalculator.controls.AddRange(@($StartYearLabel, $StartYear, $EndYearLabel, $EndYear, $PrincipalLabel, $Principal, $SalaryLabel, $Salary,
            $EmployeeContributionPercentageLabel, $EmployeeContributionPercentage, $CompanyContributionPercentageLabel, $CompanyContributionPercentage,
            $CompanyMaxContributionPercentageLabel, $CompanyMaxContributionPercentage, $AnnualIncreaseLabel, $AnnualIncrease, $InterestRateLabel, $InterestRate, $NumContributionsPerYearLabel,
            $NumContributionsPerYear, $OKButton, $CancelButton))
    $FormResults = $RetirementCalculator.Showdialog()

    
} #End Function 


 
#Call the Function 
$Results = New-RetirementData
