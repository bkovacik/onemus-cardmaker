require_relative 'excelx_facade'
require_relative 'google_drive_facade'

class FacadeFactory
  def initialize(workbook)
    @workbook = workbook
  end

  def create(ws)
    if (ws.class == String)
      return ExcelxFacade.new(@workbook.sheet(ws))
    elsif (ws.class == Roo::Excelx)
      return ExcelxFacade.new(ws)
    elsif (ws.class == GoogleDrive::Worksheet)
      return GoogleDriveFacade.new(ws)
    end
  end
end
