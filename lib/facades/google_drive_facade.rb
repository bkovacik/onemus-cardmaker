require 'google_drive'

require_relative 'worksheet_facade'

class GoogleDriveFacade < WorksheetFacade
  def getTitle()
    return @ws.title
  end

  def getNumRows()
    return @ws.num_rows
  end

  def getNumCols()
    return @ws.num_cols
  end

  def getCell(row, col)
    return @ws[row, col]
  end
end
