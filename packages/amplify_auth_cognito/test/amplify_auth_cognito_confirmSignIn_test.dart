/*
 * Copyright 2020 Amazon.com, Inc. or its affiliates. All Rights Reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License").
 * You may not use this file except in compliance with the License.
 * A copy of the License is located at
 *
 *  http://aws.amazon.com/apache2.0
 *
 * or in the "license" file accompanying this file. This file is distributed
 * on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either
 * express or implied. See the License for the specific language governing
 * permissions and limitations under the License.
 */

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_auth_cognito/method_channel_auth_cognito.dart';
import 'package:amplify_core/amplify_core.dart';

extension IsEqual on SignInResult {
  // This method only checks the length of the additionalInfo field, and the values of all other fields
  bool isMostlyEqual(SignInResult comparator) {
    return comparator.isSignedIn == isSignedIn &&
      comparator.nextStep.signInStep == nextStep.signInStep &&
      comparator.nextStep.additionalInfo.length == nextStep.additionalInfo.length &&
      comparator.nextStep.codeDeliveryDetails.destination == nextStep.codeDeliveryDetails.destination &&
      comparator.nextStep.codeDeliveryDetails.attributeName == nextStep.codeDeliveryDetails.attributeName &&
      comparator.nextStep.codeDeliveryDetails.deliveryMedium == nextStep.codeDeliveryDetails.deliveryMedium;
  }
}

void main() {
  const MethodChannel authChannel = MethodChannel('com.amazonaws.amplify/auth_cognito');
  const MethodChannel coreChannel = MethodChannel('com.amazonaws.amplify/core');

  Amplify amplify = new Amplify();
  AmplifyAuthCognito auth = AmplifyAuthCognito();

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    coreChannel.setMockMethodCallHandler((MethodCall methodCall) async {
      return true;
    });
  });

  tearDown(() {
    authChannel.setMockMethodCallHandler(null);
    coreChannel.setMockMethodCallHandler(null);
  });

  test('confirmSignIn request returns a SignInResult', () async {

    authChannel.setMockMethodCallHandler((MethodCall methodCall) async {
      if (methodCall.method == "confirmSignIn") {
        assert(methodCall.arguments["data"] is Map);
        assert(methodCall.arguments["data"]["confirmationCode"] is String);
        assert(methodCall.arguments["data"]["confirmationCode"] == 'iAmLegit');
        return {
          "isSignedIn": false,
          "nextStep": {
            "signInStep": "DONE",
            "codeDeliveryDetails":  {
              "deliveryMedium": "EMAIL",
              "attributeName": "email",
              "destination": "test@test.test"
            }
          }
        };
      } else {
        return true;
      }     
    });

    await amplify.addPlugin(authPlugins: [auth]);
    await amplify.configure("{}");
    var expectation = CognitoSignInResult(
      isSignedIn: false, 
      nextStep: AuthNextSignInStep(
        additionalInfo: {},
        codeDeliveryDetails: {
          "deliveryMedium": "EMAIL",
          "attributeName": "email",
          "destination": "test@test.test"
        },
        signInStep: "DONE",
      )
    );
    var res = await Amplify.Auth.confirmSignIn(confirmationValue: "iAmLegit");
    expect(true, res.isMostlyEqual(expectation));
  });

  test('signIn thrown PlatFormException results in AuthError', () async {
    authChannel.setMockMethodCallHandler((MethodCall methodCall) async {
      if (methodCall.method == "confirmSignIn") {
        assert(methodCall.arguments["data"] is Map);
        assert(methodCall.arguments["data"]["confirmationCode"] is String);
        return throw PlatformException(code: "AMPLIFY_EXCEPTION", message: "AMPLIFY_CONFIRM_SIGNIN_FAILED", details: {} );
      } else {
        return true;
      }     
    });
    AuthError err;
    try {
      await Amplify.Auth.confirmSignIn(confirmationValue: "iAmNotLegit");
    } catch (e) {
      err = e;
    } 
    expect(err.cause, "AMPLIFY_CONFIRM_SIGNIN_FAILED");
    expect(err, isInstanceOf<AuthError>());
  });
}
