require 'roo'

require_relative 'worksheet_facade'

class ExcelxFacade < WorksheetFacade
  def getTitle()
    return @ws.default_sheet
  end

  def getNumRows()
    return @ws.last_row
  end

  def getNumCols()
    return @ws.last_column
  end

  def getCell(row, col)
    return @ws.cell(row, col).to_s
  end
end
