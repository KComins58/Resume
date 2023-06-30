//Kyle Comins

#include <stdio.h>
#include <stdlib.h>
#include <time.h>

int aCards[52];
char aValue[13] = {'A', '2', '3', '4', '5', '6', '7', '8' , '9' ,'T' , 'J', 'Q' , 'K'};
char aSuit[4] = {'S','H', 'D', 'C'};

int main()
{
    int k, l, iCount = 0, iOption = 0, iCurrent = 0, iPeople, iStart = 0;
    char sInput[100], sOption[100];

    for (k = 0; k < 52; k++)
    {
        if (k % 13 == 0)
            iCount += 1;
        aCards[k] = (iCount * 100) + k;
    }

    shuffle(aCards, 52);

    while(iOption != 3)
    {
        printf("\n| 1. Print out shuffled Deck of Cards|\n| 2. Play a hand |\n| 3. Exit |\n\n What would you like to do: ");
        fgets(sOption,sizeof(sOption), stdin);
        sscanf(sOption, "%d", &iOption);

        switch(iOption)
        {
            case 1: printCards(aCards, 0, 52);
                    break;
            case 2: printf("How many people need to be dealt hands?");
                    scanf("%d",&iPeople);
                    for (k = 1; k < iPeople+1; k++)
                    {
                        printf("Player %d's hand:\n", k);
                        printCards(aCards, iCurrent, iCurrent + 2);
                        iCurrent += 2;
                        printf("\n");
                    }
                    printf("Cards on flop: \n");
                    getch();
                    printCards(aCards, iCurrent, iCurrent + 3);
                    iCurrent += 3;
                    printf("\n");
                    printf("Card on turn: \n");
                    getch();
                    printCards(aCards, iCurrent, iCurrent + 1);
                    iCurrent += 1;
                    printf("\n");
                    printf("Card on river: \n");
                    getch();
                    printCards(aCards, iCurrent, iCurrent + 1);
                    iCurrent += 1;
                    printf("\n");
                    break;
        }
    }
    return 0;

return 0;
}

void printCards(int *arr, int start, int end)
{
    int k, l;
    for (k = start; k < end; k++)
    {
        if ((arr[k] - 400) > 0)
        {
            l = (arr[k] - 400);
            printf("Diamonds ");
        }
        else if ((arr[k] - 300) > 0)
        {
            l = arr[k] - 300;
            printf("Hearts ");
        }

        else if ((arr[k] - 200) > 0)
        {
            l = arr[k] - 200;
            printf("Spades ");
        }

        else
        {
            l = arr[k] - 100;
            printf("Clubs ");
        }
        while (l - 13 >= 0)
            l = l - 13;
        if (aValue[l] != 'T')
            printf("%c\n", aValue[l]);
        else printf("10\n");
    }
}

void shuffle(int *arr, size_t n)
{
    if (n > 0)
    {
        size_t k;
        srand(time(NULL));
        for (k = 0; k < n - 1; k++)
        {
          size_t l = k + rand() / (RAND_MAX / (n - k) + 1);
          int t = arr[l];
          arr[l] = arr[k];
          arr[k] = t;
        }
    }
}
