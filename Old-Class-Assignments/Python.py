#!/usr/bin/env python3

#imports
import tkinter as tk
import re
import os
import datetime

#Intilialise Program Loop
New_golfer = True
while New_golfer == True:

    #Variables that need to be reset every new golfer
    Courses = list() #Major list
    Diff = 0
    x = 0
    Name = ""

    #Naming files the names of golfers for ease and checking if they have a folder already
    while Name == "":
        Name = input("Enter Golfers name: ")
        if Name == "":
            print("Please enter a golfers name:\n")
    if os.path.isfile(Name+'.txt') == True: #Checking if textfile with the name already exists
        File = open(Name +'.txt',"r+") #if it already exists open to read and write
    else: 
        File = open(Name + '.txt',"w+") #if it doesn't exist create and open to read and write
        Force = True
    for Line in File:
        Line = Line.split() #Seperate all items in file into lists for each line
        Courses.append(Line)

    K = int(input("\nHow many courses do you want to enter(if any) : ")) #Number of courses to enter or 0 to check what it is currently
    
    if Force == True:
        while K == 0:
            K = int(input("\nHow many courses do you want to enter(At least 1) : "))

    #Course Loop
    while x < K:
        #Course Initialise
        Score = 0
        Par = 0
        Slope = 0

        #Validation
        CourseName = input("\nPlease enter name of course: ")
        while Score < 59:
            Score = int(input("Please enter Score over 59: "))
        while (Par < 72) or (Par > 76):
            Par = int(input("Please enter Par between 72 and 76: "))
        while (Slope < 122) or (Slope > 126):
            Slope = int(input("Please enter Slope between 122 and 126: "))
        Date = str(datetime.date.today()) #Current Date

        Courses.append((CourseName, Score, Par, Slope, Date)) #Add all new course data to Array

        File.write(CourseName + ' ' + str(Score) + ' ' + str(Par) + ' ' + str(Slope)+ ' ' + Date +'\n') #Add all new course data to File

        x += 1
    File.close() #Always close text file when done working with it
    Best = 999
    Worst = 0

    #Calculate Differential for all course
    for m in Courses: 
        Score = int(m[1])
        Par = int(m[2])
        Slope = int(m[3])
        if Score < Best: #Set new best course data
            Best = Score
            BestCourse = (m[0])
            BestPar = Par
            BestSlope = Slope
            BestDate = (m[4])
        if Score > Worst: #Set new worst course data
            Worst = Score
            WorstCourse = (m[0])
            WorstPar = Par
            WorstSlope = Slope
            WorstDate = (m[4])
        Diff += float(((Score - Par)*113)/Slope) #Calculate handicap differential

    #Check if enough courses played
    if len(Courses) < 5:
        Handi = False
    else:
        Handi = True
        Handicap = int(round((Diff/len(Courses))*0.96,0)) #Handicap Calculation

    #Output Name & Handicap
    if Handi == True:
        print("\nName: "+Name+"\tHandicap: "+str(Handicap))
        if Handicap > 10:
            Ranking = "Hacker with a Handicap of: " + str(Handicap)
        elif Handicap > 5:
            Ranking = "Average with a Handicap of: " + str(Handicap)
        elif Handicap > 0:
            Ranking = "Duffer with a Handicap of: " + str(Handicap)
        else: Ranking = "Championship with a Handicap of: " + str(Handicap)
    else: Ranking = 'Rookie - Courses to Handicap is: '+str(5 - len(Courses))
    
    #String to put into Label with entered information
    CourseOut = ''
    ScoreCard = 'Course\t\tScore\tPar\tSlope\tDate\n'
    for l in range(0, len(Courses)):
        CourseOut = str(Courses[l][0]) + '\t\t' 
        for r in range(1,5):
            CourseOut += str(Courses[l][r]) + '\t'    
        ScoreCard += CourseOut+'\n'
    print(ScoreCard) #Output all scores of current player
    ScoresOutput = '\tCourse\tPar\tScore\tSlope\tDate\n'
    ScoresOutput += 'Best\t'+BestCourse+'\t'+str(BestPar)+'\t'+str(Best)+'\t'+str(BestSlope)+'\t'+BestDate+'\n' #Best Score + Details
    ScoresOutput += 'Worst\t'+WorstCourse+'\t'+str(WorstPar)+'\t'+str(Worst)+'\t'+str(WorstSlope)+'\t'+WorstDate+'\n' #Worst Score + Details
    print(ScoresOutput) #Output best + worst of current player

    #Output Club Players
    path = os.getcwd() #Path to Program
    Member = list() #Create a list for Club Players
    PlayerOutput = 'Member \t Handicap \t Ranking \n'
    
    #Run loop in current directory
    for file_name in os.listdir(path): 
        if file_name.endswith('.txt'): #Find all .txt files in folder
            TempName = file_name.split(".")[0] #Take name part of file
            TempFile = open(file_name,"r+")
            TempCourses = list() #List that gets reset each file
            for TempLine in TempFile: 
                TempLine = TempLine.split() #Seperate all items in file into lists for each line
                TempCourses.append(TempLine) #Add to end of List
            TempFile.close() #Always close file
            TempDiff = 0
            TempCount = 0
            for m in TempCourses: #Calculate Differential for all course
                TempCount += 1
                TempScore = int(m[1])
                TempPar = int(m[2])
                TempSlope = int(m[3])
                TempDiff += float(((TempScore - TempPar)*113)/TempSlope)
            if TempCount > 0:
                TempHandicap = int(round((TempDiff/TempCount)*0.96,0))
            TempCourses.clear()
            if TempCount < 5:
                TempRanking = "Rookie"
                TempHandicap = 99 #Over Highest Handicap Possible
            else:
                if TempHandicap > 10:
                    TempRanking = "Hacker"
                elif TempHandicap > 5:
                    TempRanking = "Average"
                elif TempHandicap > 0:
                    TempRanking = "Duffer"
                else: TempRanking = "Championship"
            Member.append((TempHandicap,TempName,TempRanking))
            
    Member.sort()
    PlayerOutput = 'Player \t Handicap \t Ranking \n'
    for t in range(0, len(Member)):
        if Member[t][0] == 99: #Value Assigned to players that haven't played enough courses i.e Rookie
            PlayerOutput += str(Member[t][1])+'\t'+"N/A"+'\t\t'+str(Member[t][2])+'\n'
        else:    
            PlayerOutput += str(Member[t][1])+'\t'+str(Member[t][0])+'\t\t'+str(Member[t][2])+'\n'
    print(PlayerOutput)

    #Outputs in both the Python IDLE GUI and TKinter
    print('Output in tkinter')

    #Create Window / tkinter GUI
    window = tk.Tk()

    #Label Course Scores
    label1 = tk.Label(
        window, #Intilised Window
        text = ScoreCard, #Text on label
        fg = "black",
        bg = "white",
        anchor = tk.N, #Position S,W,N,E,SW,NW,NE,SE
    )

    #Label Handicap + Ranking
    label2 = tk.Label(
        window, 
        text = Name + "'s Handicap Ranking is: " + Ranking, 
        height = 30,
        width = 100,
        fg = "black",
        anchor = tk.SW, 
        bg = "white"
    )

    #Label Best + worst score
    label3 = tk.Label(
        window,
        text = ScoresOutput,
        anchor = tk.N
    )

    #Label all Club Players
    label4 = tk.Label(
        window, 
        text = PlayerOutput, 
        fg = "black",
        anchor = tk.N, 
        bg = "white"
    )

    #Pack lable into window
    label1.pack()
    label2.pack()
    label3.pack()
    label4.pack()
    #Run Window with all packed
    window.mainloop()

    #Enter a new person?
    Again = input("\nDo you want to enter another golfers info (y or n): ")
    if Again == "n":
        New_golfer = False

#End
