#  framework-ios-odptdata
====

iOS Framework for accessing ODPT(Open Data for Public Transportation) API written in Objective-C.

## Description

ODPT API is widely open to the public for fetching information for Public Transportation(Railway, Bus, Aviation) around Tokyo, Japan.
By accessing API, you can get information about Route, Station, train/bus Location, timetable, fare, station/busstop near the specified point, etc..

At the moment ( Aug. 2019 ),  there are three type of ODPT API and similar API.
* TokyoMetro OpenData API <https://developer.tokyometroapp.jp/info>
* OpenData for Public Transporatation API     <https://developer.odpt.org/ja/info>
* API for The 3rd Open Data Challenge for Public Transportation in Tokyo <https://tokyochallenge.odpt.org>

The latter API has the most enrich content and this framework has been developed for this.

ODPT API is RESTful Web API, so App need to have appropriate function for accessing to API.
Otherwise, App is not able to provide great experience to App user.

This framework has been developed for iOS app directly accessing to ODPT API, has the following feature.
* Sequential http Request to avoid access rate limitation.
* Cache the fetched data.
* Efficient duplicate access at same time.
* Adjust original ODPT data content for easy to use in App.
* Extendable archtecture.

By above feature, even if mass access in a short period at launch App, or discrete access corresponding to App user operation,
this framework access ODPT API effciently without failure.

This framework is used to TokyoLines iOS Free App version 2.0.4 or later. 

This framework developer is **unrelated** to administrator of ODPT API.
To Use this framework effectively, you should agree and comply the API Use Permission Rules set by each API administrator.


## Requirement

This framework is dependent only on function provided by Apple.
No need for thirdparty library.

This framework has been developed and built with Xcode 10.2 .

To access to API, you should get EndPointURL and token for your app.
For API for The Open Data Challenge for Public Transportation in Tokyo, check URL below. 
<https://tokyochallenge.odpt.org>


## Install

Using git or Xcode, download files to your environment.
When using Xcode, you should click the "Clone an existing project" at "Welcome to Xcode" dialog.

Recommended extracting the files to one level down with making some directory.


## Usage 

### add Framework to your App Project

Close Xcode once, Open the App Project you developing.
Drag and Drop the ODPTData.xcodeproj file of this framework to **under the your app project** at source list 
**NOT** to same level with your app project.

Select Project file at source list and select build target.
Select "General" - "Embedded Binaries", click "+" button, and select framework "ODPTData.framework".

By this action, your App project will depend on this framework.
This framework will be build prior to build your App, and link automatically.

### preparation for App written in Swift

If Your App Project is written in Swift, you must make bridge header file to call function of this framework,
because this framework is written in Objective-C.

Add new header file(*.h) to your app project normally.
File name is desirable that "[XXXXX]-Bridging-Header.h" , [XXXXX] is replaced to your app product name.

Select Project file at source list and select build target.
Select "Build Settings" - "Swift Compilar - General", input below at item "Objective-C Bridging Header".

> $(SRCROOT)/$(PROJECT)/[XXXXX]-Bridging-Header.h

Open this bridging header file, add below line.

> @import ODPTData;


### call function of Framework

By above sequence, ODPTData.h and other header files will be visible at your *.m or *.swift source file,
Code Snippet in Xcode become in function.

In your source code that use function of framework, you should include ODPTData.h .

To use framework, you instantiate ODPTDataController class first.

> var dataSource = ODPTDataController ( apiCacheDirectory:"zzzz...",  userDataDirectory:"yyyy", endPointURL:"https://xxxxxx", token:"xxxxx" )

> ODPTDataController *dataSource = [[ODPTDataController alloc] initWithAPICacheDirectory:[self cacheDirectory]
>withUserDataDirectory:[self userDataDirectory]
>withEndPointURL:endPointURL
>withToken:token];

call prepare  message  of this instance.

> dataSource.prepare()

> [dataSource prepare];

call various utility method of instance of ODPTDataController class.

> dataSource!.request(withOwner: self, stationTitleForIdentifier: ident) { (title: String?) in
>     print(ident + " -> " + title!);
>  }

Almost method need to be called with closure, because ansynchronous behavior.


## Usage - Test Code

Some test code is prepared for framework and included in this software.
It is better to run test code first if you would like to modify this framework.

### make token.txt / endpoint.txt

make token.txt  with token get from API administrator.
This file contains only string for token.

make endpoint.txt with EndPointURL get from API administrator.
This file contains only string for EndPoint URL that begin with "https://" and end with "/v4" in case of  API for The 3rd Open Data Challenge for Public Transportation in Tokyo. 

put these files to somewhere which is not managed by git  not to expose the token and EndPointURL.


### modify Run Script for ODPTDataTests build target

Close Xcode once, Open this Framework project "ODPTData.xcodeproj" only in Xcode.
In Build target setting of Xcode,  select the "ODPTDataTests".
select the "Build Phases" in top of window, open "Run Script". 
This block represents a shell script that should be executed before building the test code.

modify variable "ODPT_TOKEN_FILE" and "ODPT_ENDPOINT_FILE" to the path that you put "token.txt" and "endpoint.txt".

### run test

Source files for Test placed at under "ODPTDataTests" .
For example, select "ODPTDataTests+Controller.m", search "- (void) testRequestLineTitle" .
Diamond mark will be found at left side of message name, and click.
Run only this test that fetch some Railway title from API.
Test Result will be show at console bottom of window.


## License

This software is released under the MIT License.

To Access ODPT API with this software, you should agree and comply the API Use Permission Rules separately this software license.

You can submit your work contain this software to the contest "The Open Data Challenge for Public Transportation in Tokyo" and other.
Even if your work wins a prize in the contest, the developer of this software does not claim any winner's rights.


## Author

Takehito Ikema 

