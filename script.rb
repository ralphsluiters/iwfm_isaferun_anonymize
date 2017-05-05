#!ruby
require 'date'
 
DATUM_AUSGETRETEN = Date.today - 180
# DATUM_AUSGETRETEN = Date.new(2007,1,1)
GROUPS_TO_KEEP = [2,1041] # Liste von Gruppen, deren Mitarbeiter ignoriert werden.
 
 
 
 
class Date
 
    ############################################################################
    #
    #   Method Name:-   to_s
    #   Description:-   Convert a date to String.
    #   Parameters:-    None.
    #   Return Values:- String containing a localised Date.
    #
    ############################################################################
    def to_s
        case $ISPSLanguage
            when ISPS::LANG_GERMAN #German
                format('%02d.%02d.%04d', self.day, self.month, self.year)
            else
                format('%04d-%02d-%02d', self.year, self.month , self.day)
        end
    end #to_s
end #class Date
 
 
class Script
                RIGHT_ALIGN                   = {:style => 'text-align: right;'}
                LEFT_ALIGN                       = {:style => 'text-align: left;'}
 
  def ausg_datum(string)
    t,m,j = string.split(".") if string
 
    Date.new(j.to_i,m.to_i,t.to_i)
  rescue Exception => e
     Date.today - string.to_i
  end 
  
  def staff_in_group
    staff_list=[]
    groups = []
    session.userGroups.each do |g|
      if GROUPS_TO_KEEP.include?(g.id)
        groups << g.name
        g.member.each do |u|
          staff_list << u.staffId if u.staff?
        end
      end
    end
    [staff_list.uniq, groups]
  end
 
  def onStart
    session
    @ausgetreten = ausg_datum(args['ausgetreten'])
    @neue_mitarbeiter = (args['neue_mitarbeiter'] == "1")
    @mitarbeiter_loeschen = (args['mitarbeiter_loeschen'] == "1")
    @staff_to_ignore, @groups  = staff_in_group   
  end #onStart
 
 
  def ausgetretene_ma(nur_neue)
    ausg = Array.new
    ausg_alt = Array.new
    session.staffs.each do |s|
#      next unless s.id == 2962
      if s.leaveDate && s.leaveDate < @ausgetreten
        if nur_neue
          if s.name != "XXX, XXX"
            ausg << s
          else
            ausg_alt << s
          end
        else
          ausg << s
        end
      end
    end
    [ausg, ausg_alt]
  end
 
 
 
  def onView #generates the view
    
    puts bold "Löschen/Anonymisieren ausgetretener Mitarbeiter"    
    ausg = inp('ausgetreten',@ausgetreten)
    ausg.onChange = "JavaScript:LoadAgain();"
    cb1 = checkBox('neue_mitarbeiter',"",@neue_mitarbeiter)
    cb1.onChange = "JavaScript:LoadAgain();"
    cb2 = checkBox('mitarbeiter_loeschen',"",@mitarbeiter_loeschen)
    cb2.onChange = "JavaScript:LoadAgain();"
    print '<br/>'
    fs = fieldset("Parameter")
    fs << ftable([LEFT_ALIGN,"Datum oder Tage vor heute:", RIGHT_ALIGN,ausg],
                [LEFT_ALIGN,"Nur neue Mitarbeiter:",RIGHT_ALIGN, cb1],
                [LEFT_ALIGN,"Löschen:",RIGHT_ALIGN,cb2])
    puts fs
 
 
    ausg, ausg_alt = ausgetretene_ma(@neue_mitarbeiter)
    fs = fieldset("Kennzahlen")
    fs << ftable(   
      [LEFT_ALIGN,"Mitarbeiter ausgetreten vor",RIGHT_ALIGN,@ausgetreten],
      [LEFT_ALIGN,"Mitarbeiter im System:",RIGHT_ALIGN,session.staffs.size],
      [LEFT_ALIGN,"Ausgetretene MA (bereits anonymisiert):",RIGHT_ALIGN,ausg_alt.size],
      [LEFT_ALIGN,"Ausgetretene MA zu löschen/anonymisieren:",RIGHT_ALIGN,ausg.size],
      [LEFT_ALIGN,"Gruppen zu ignorieren:",RIGHT_ALIGN,@groups.join(", ")],
      [LEFT_ALIGN,"Mitarbeiter in diesen Gruppen:",RIGHT_ALIGN,@staff_to_ignore.size])
    puts fs
    puts text "Mitarbeiterliste:"
    print "<pre>"
    ausg.each do |s|
      print "IGNORE(GROUP):" if @staff_to_ignore.include?(s.id)
      print "#{s.id}: #{s.ident}, #{s.name}, #{s.leaveDate}"
      print "\n"
    end
    print "</pre>"
    puts text "'OK' drücken um löschen/anonymisieren zu starten"   
  end #onView
  
  
  def onRun
    errors = Array.new
    ausg,_ = ausgetretene_ma(@neue_mitarbeiter)
    ausg.each do |s|
      puts "Mitarbeiter #{s.id}: #{s.name} ausgetreten: #{s.leaveDate}"
      if @staff_to_ignore.include?(s.id)
        puts "Ignoriert auf Grund der Benutzergruppe!"
      else
        if @mitarbeiter_loeschen
          session.users.each do |u|
            if u.staff? && u.staffId == s.id
              u.delete!
            end
          end
          s.delete!
        else
          s.ident = "XXX_#{s.id}"
          s.birthDate = nil
          a = s.address()
 
          a.firstName = "XXX"
          a.lastName = "XXX"
          a.title = "XXX"
          a.street = "XXX"
          a.zipCode = "XXX"
          a.city = "XXX"
          a.phone ="XXX"
          a.phone2 ="XXX"
          a.email =""
          a.email2 =""
          s.address = a
          s.idCards.each do |i|
            i.cardNumber="XXX"
            errors << "Error writing Card number for #{s.id}" unless i.write
          end
          s.write!
       
          session.users.each do |u|
            if u.staff? && u.staffId == s.id
              u.name = "XXX_#{u.id}"
              u.write!
            end
          end
        end
      end  
    end
    puts "Done!"
    errors.each {|e| puts text e} if errors.size>0
  end #onRun
  
end #class Script