let
  Source = Folder.Files("C:\data\HR_Source\03_Monthly_Attendance"),
    #"Filtered Hidden Files1" = Table.SelectRows(Source, each [Attributes]?[Hidden]? <> true),
    #"Invoke Custom Function1" = Table.AddColumn(#"Filtered Hidden Files1", "Transform File", each #"Transform File"([Content])),
    #"Renamed Columns1" = Table.RenameColumns(#"Invoke Custom Function1", {"Name", "Source.Name"}),
    #"Removed Other Columns1" = Table.SelectColumns(#"Renamed Columns1", {"Source.Name", "Transform File"}),
    #"Expanded Table Column1" = Table.ExpandTableColumn(#"Removed Other Columns1", "Transform File", Table.ColumnNames(#"Transform File"(#"Sample File"))),
    #"Changed Type" = Table.TransformColumnTypes(#"Expanded Table Column1",{{"Source.Name", type text}, {"EmployeeID", type text}, {"Year", Int64.Type}, {"Month", Int64.Type}, {"WorkingDays", Int64.Type}, {"DaysPresent", Int64.Type}, {"SickLeaveDays", Int64.Type}, {"AnnualLeaveDays", Int64.Type}, {"UnplannedAbsences", Int64.Type}, {"OvertimeHours", Int64.Type}}),
    #"Grouped Rows" = Table.Group(#"Changed Type", {"EmployeeID"}, {{"TotalWorkingDays", each List.Sum([WorkingDays]), type nullable number}, {"TotalPresentDays", each List.Sum([DaysPresent]), type nullable number}, {"TotalSickLeave", each List.Sum([SickLeaveDays]), type nullable number}, {"TotalAnnualLeave", each List.Sum([AnnualLeaveDays]), type nullable number}, {"TotalUnplannedAbsences", each List.Sum([UnplannedAbsences]), type nullable number}, {"TotalOvertimeHrs", each List.Sum([OvertimeHours]), type nullable number}})
in
  #"Grouped Rows"