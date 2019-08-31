//
//  ODPTDataConstant.h
//
//  Copyright (c) 2019 Takehito Ikema
//
//  This software is released under the MIT License.
//  https://opensource.org/licenses/mit-license.php
//

#ifndef ODPTDataConstant_h
#define ODPTDataConstant_h

enum {
    ODPTDataIdentifierTypeUndefined = -1,
    ODPTDataIdentifierTypeLine = 0,
    ODPTDataIdentifierTypeStation = 1,
};

enum {
    ODPTDataLineTypeUndefined = -1,
    ODPTDataLineTypeRailway = 0,
    ODPTDataLineTypeBus = 1
};

enum {
    ODPTDataStationTypeUndefined = -1,
    ODPTDataStationTypeTrainStop = 0,
    ODPTDataStationTypeBusStop = 1
};

enum {
    ODPTDataLineStatusLevelNormal = 0,
    ODPTDataLineStatusLevelDelay = 1,
    ODPTDataLineStatusLevelSuspend = 2
};

#endif /* ODPTDataConstant_h */
