//Kyle Comins
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <cstddef>
#include <iostream>
#include <bits/stdc++.h>
#include <string>
using namespace std;

struct Node
{
    public:
    int data;
    string Name;
    struct Node* next;
} Node;

struct Node* swap(struct Node* ptr1, struct Node* ptr2)
{
    struct Node* tmp = ptr2->next;
    ptr2->next = ptr1;
    ptr1->next = tmp;
    return ptr2;
}

int bubbleSort(struct Node** head, int count, string *arr, int *data)
{
    struct Node** h;
    int i, j, swapped, iTemp;
    string sTemp;

    for (i = 0; i <= count; i++)
    {
        h = head;
        swapped = 0;
        for (j = 0; j < count - i - 1; j++)
        {
            struct Node* p1 = *h;
            struct Node* p2 = p1->next;

            if (p1->data < p2->data)
            {
                *h = swap(p1, p2);
                sTemp = arr[j];
		iTemp = data[j];
		arr[j]=arr[i];
		data[j]=data[i];
		arr[i]=sTemp;
		data[i]=iTemp;
                swapped = 1;
            }
            h = &(*h)->next;
        }
        if (swapped == 0)
            break;
    }
}

void printList(struct Node* n, string *arr)
{
    int k = 0;
    while (n != NULL)
    {
        cout << arr[k] << "\t" << n->data <<endl;
        n = n->next;
        cout;
        k ++;
    }
    cout << endl;
}

void sortName(int *data, string *arr, int iCount)
{
    	int n,i,j;
	string sTemp;
	int iTemp;
	for(i=0;i<iCount;i++)
	{
		for(j=i+1;j<iCount;j++)
		{
			if(data[i]<data[j])
			{
				sTemp = arr[i];
				iTemp = data[i];
				arr[i]=arr[j];
				data[i]=data[j];
				arr[j]=sTemp;
				data[j]=iTemp;
			}
		}
	}
}

void insertAtTheBegin(struct Node** start_ref, int data)
{
    	struct Node* ptr1 = (struct Node*)malloc(sizeof(struct Node));
	ptr1->data = data;
	ptr1->next = *start_ref;
	*start_ref = ptr1;
}

int main()
{
    int aMarks[30] = { }, iCount = 0, iOption = 0, iVal, k;
    string aNames[30] = { };
    char sOption[100], sVal[100];
    struct Node* start = NULL;
    while (iOption != 3)
    {
        cout << "\n| 1. Add Test Score|\n| 2. Print Bubble Order |\n| 3. Exit |\n\nWhat would you like to do: ";
        fgets(sOption,sizeof(sOption), stdin);
        sscanf(sOption, "%d", &iOption);
        switch(iOption)
        {
        case 1:
            cout << "Enter student name: ";
            getline(cin,aNames[iCount]);
            cout << "Enter student grade: ";
            fgets(sVal,sizeof(sVal), stdin);
            sscanf(sVal, "%d", &iVal);
            aMarks[iCount] = iVal;
            iCount ++;
            break;
        case 2:
            for (k = 0; k < iCount; k++)
                insertAtTheBegin(&start, aMarks[k]);
            bubbleSort(&start, iCount, aNames, aMarks);
            cout <<"Sorted List: \n";
            printList(start, aNames);
            break;
        }
    }
}
