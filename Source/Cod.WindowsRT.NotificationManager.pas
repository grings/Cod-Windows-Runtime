{***********************************************************}
{                Codruts Notification Manager               }
{                                                           }
{                        version 1.2                        }
{                                                           }
{                                                           }
{                                                           }
{                                                           }
{                                                           }
{              Copyright 2024 Codrut Software               }
{***********************************************************}

{$SCOPEDENUMS ON}

unit Cod.WindowsRT.NotificationManager;

interface

uses
  // System
  Winapi.Windows, System.SysUtils, System.Classes,

  // Windows RT (Runtime)
  Win.WinRT,
  Winapi.Winrt,
  Winapi.Winrt.Utils,
  Winapi.DataRT,
  Winapi.UI.Notifications,

  // Winapi
  Winapi.CommonTypes,
  Winapi.Foundation,

  // Requirements
  Cod.WindowsRT.AppRegistration,

  // Resources
  Cod.WindowsRT.Exceptions,
  Cod.WindowsRT.ResourceStrings,

  // Cod Utils
  Cod.WindowsRT,
  Cod.Registry;

const
  ssNotificationUnknownCardinalValue = 'Unknown cardinal value.';

type
  // Predefine
  TNotification = class;
  TUserInputMap = class;

  // Re-define
  ToastNotificationPriority = Winapi.UI.Notifications.ToastNotificationPriority;
  NotificationMirroring = Winapi.UI.Notifications.NotificationMirroring;
  NotificationSetting = Winapi.UI.Notifications.NotificationSetting;

  // Cardinals
  TSoundEventValue = (
    Default,
    NotificationDefault,
    NotificationIM,
    NotificationMail,
    NotificationReminder,
    NotificationSMS,
    NotificationLoopingAlarm,
    NotificationLoopingAlarm2,
    NotificationLoopingAlarm3,
    NotificationLoopingAlarm4,
    NotificationLoopingAlarm5,
    NotificationLoopingAlarm6,
    NotificationLoopingAlarm7,
    NotificationLoopingAlarm8,
    NotificationLoopingAlarm9,
    NotificationLoopingAlarm10,
    NotificationLoopingCall,
    NotificationLoopingCall2,
    NotificationLoopingCall3,
    NotificationLoopingCall4,
    NotificationLoopingCall5,
    NotificationLoopingCall6,
    NotificationLoopingCall7,
    NotificationLoopingCall8,
    NotificationLoopingCall9,
    NotificationLoopingCall10
  );
  TSoundEventValueHelper = record helper for TSoundEventValue
    function ToString: string; inline;
  end;

  TImagePlacement = (Default, Hero, LogoOverride);
  TImageCrop = (Default, None, Circle);
  TInputType = (Text, Selection);
  TActivationType = (
    ///  <summary> Default activation </summary>
    Default,
    ///  <summary> The host application will be launched. </summary>
    Foreground,
    ///  <summary> Run the activation in the background via a task </summary>
    Background,
    ///  <summary> Start another application via protocol. Eg: "ms-calculator://" </summary>
    Protocol,
    ///  <summary> System handle </summary>
    System
  );
  TActivationTypeHelper = record helper for TActivationType
    function ToString: string; inline;
  end;

  TToastDuration = (
    ///  <summary> Use default: short </summary>
    Default,
    ///  <summary> Display for 7s </summary>
    Short,
    ///  <summary> Display for 25s </summary>
    Long
  );
  TToastDurationHelper = record helper for TToastDuration
    function ToString: string; inline;
  end;

  TAudioMode = (
    ///  <summary> The notification controls the audio </summary>
    Default,
    /// <summary> No audio </summary>
    Muted,
    ///  <summary> Custom audio overrides all toast sounds </summary>
    Custom
  );
  TNotificationRank = (
    Default,
    Normal,
    High,
    Topmost
  );
  TToastScenario = (
    ///  <summary> Default notification behaviour </summary>
    Default,
    ///  <summary> Show on screen until the user takes action, NotificationLoopingAlarm selected by default </summary>
    Alarm,
    ///  <summary> Show on screen until the user takes action </summary>
    Reminder,
    ///  <summary> Show on screen until the user takes action, NotificationLoopingCall selected by default </summary>
    IncomingCall,
    ///  <summary> Urgent </summary>
    Urgent
    );
  TToastScenarioHelper = record helper for TToastScenario
    function ToString: string; inline;
  end;
  TToastDismissReason = ToastDismissalReason;

  // Exceptions
  EWinRTNotification = class(Exception);
  EWinRTNotificationNotActive = class(Exception);
  EWinRTNotificationNoTag = class(Exception);
  EWinRTNotificationCreationFailed = class(Exception);
  EWinRTNotificationNotVisible = class(EWinRTNotification);
  EWinRTNotificationAlreadyPosted = class(EWinRTNotification);
  EWinRTNotificationFeatureNotSupported = class(EWinRTNotification);
  EWinRTNotificationUpdateFailed = class(EWinRTNotification);
  EWinRTNotificationNotificationNotFound = class(EWinRTNotification);
  ENotificationUnknownCardinal = class(EWinRTNotification);

  // Events
  TOnToastActivated = procedure(Sender: TNotification; Arguments: string; UserInput: TUserInputMap) of Object;
  TOnToastDismissed = procedure(Sender: TNotification; Reason: TToastDismissReason) of Object;
  TOnToastFailed = procedure(Sender: TNotification; ErrorCode: HRESULT) of Object;

  // Record
  TToastComboItem = record
    ID: string;
    Content: string;
  end;

  // Events
  TNotificationEventHandler = class(TInspectableObject)
    private
      FNotification: TNotification;
      FToken: EventRegistrationToken;

      ///  <summary>
      ///  Re-subscribe to the notification event. Used when the notification is reset
      ///  </summary>
      procedure Resubscribe; virtual;
      ///  <summary>
      ///  Subscribe to the notification event
      ///  </summary>
      procedure Subscribe; virtual; abstract;
      ///  <summary>
      ///  Unsubscribe from the notification event
      ///  </summary>
      procedure Unsubscribe; virtual; // inherited; must be called after the token is unregistered!!

      // Getters
      function GetSubscribed: boolean;
    public
      property Subscribed: boolean read GetSubscribed;

      constructor Create(const ANotification: TNotification); virtual;
      destructor Destroy; override;
  end;

  TNotificationActivatedHandler = class(TNotificationEventHandler, TypedEventHandler_2__IToastNotification__IInspectable,
    TypedEventHandler_2__IToastNotification__IInspectable_Delegate_Base)
    procedure Invoke(sender: IToastNotification; args: IInspectable); safecall;

    procedure Subscribe; override;
    procedure Unsubscribe; override;
  end;

  TNotificationDismissedHandler = class(TNotificationEventHandler, TypedEventHandler_2__IToastNotification__IToastDismissedEventArgs,
    TypedEventHandler_2__IToastNotification__IToastDismissedEventArgs_Delegate_Base)
    procedure Invoke(sender: IToastNotification; args: IToastDismissedEventArgs); safecall;

    procedure Subscribe; override;
    procedure Unsubscribe; override;
  end;

  TNotificationFailedHandler = class(TNotificationEventHandler, TypedEventHandler_2__IToastNotification__IToastFailedEventArgs,
    TypedEventHandler_2__IToastNotification__IToastFailedEventArgs_Delegate_Base)
    procedure Invoke(sender: IToastNotification; args: IToastFailedEventArgs); safecall;

    procedure Subscribe; override;
    procedure Unsubscribe; override;
  end;

  // Values
  TToastValue = class
  public
    function ToXML: string; virtual; abstract;
  end;
  (* String value *)
  TToastValueString = class(TToastValue)
  private
    Value: string;
  public
    function ToXML: string; override;

    constructor Create(AValue: string);
  end;
  (* Single value *)
  TToastValueSingle = class(TToastValue)
  private
    Value: single;
  public
    function ToXML: string; override;

    constructor Create(AValue: single);
  end;
  (* Bindable by ID value *)
  TToastValueBindable = class(TToastValueString)
    function ToXML: string; override;
  end;

  // Notification data
  TNotificationData = class
  private
    Data: INotificationData;
      
    function GetValue(Key: string): string;
    procedure SetValue(Key: string; const Value: string);
    function GetSeq: cardinal;
    procedure SetSeq(const Value: cardinal);

  public
    property InterfaceValue: INotificationData read Data;

    // Seq
    property SequenceNumber: cardinal read GetSeq write SetSeq;
    procedure IncreaseSequence;
    
    // Proc
    procedure Clear;
    function ValueCount: cardinal;
    function ValueExists(Key: string): boolean;
    procedure DeleteValue(Key: string);

    // Manage
    property Values[Key: string]: string read GetValue write SetValue; default;
    
    constructor Create;
    destructor Destroy; override;
  end;

  // User input parser
  TUserInputMap = class
  private
    FMap: IMap_2__HSTRING__IInspectable;
  public
    function HasValue(ID: string): boolean;
    function GetStringValue(ID: string): string;
    function GetIntValue(ID: string): integer;

    constructor Create(LookupMap: IMap_2__HSTRING__IInspectable);
    destructor Destroy; override;
  end;

  // Toast notification
  TNotification = class
  private
    FPosted: boolean;
    FHidden: boolean;

    // Interfaces
    FToast: IToastNotification;
    FToast2: IToastNotification2;
    FToast3: IToastNotification3;
    FToast4: IToastNotification4;
    FToast6: IToastNotification6;

    FToastScheduled: IScheduledToastNotification;

    // Notify events
    FOnActivated: TOnToastActivated;
    FOnDismissed: TOnToastDismissed;
    FOnFailed: TOnToastFailed;
    FHandleActivated: TNotificationActivatedHandler;
    FHandleDismissed: TNotificationDismissedHandler;
    FHandleFailed: TNotificationFailedHandler;

    // Interface-access classes
    FData: TNotificationData;

    /// <summary> Free event notification objects. </summary>
    procedure FreeEvents;

    /// <summary> Initiate notification from XML doc. </summary>
    procedure Initiate(XML: TXMLInterface);

    function GetExpiration: TDateTime;
    procedure SetExpiration(const Value: TDateTime);
    function GetSuppress: boolean;
    procedure SetSuppress(const Value: boolean);
    function GetGroup: string;
    function GetTag: string;
    procedure SetGroup(const Value: string);
    procedure SetTag(const Value: string);
    function GetMirroring: NotificationMirroring;
    procedure SetMirroring(const Value: NotificationMirroring);
    function GetRemoteID: string;
    procedure SetRemoteID(const Value: string);
    procedure SetData(const Value: TNotificationData);
    function GetPriority: ToastNotificationPriority;
    procedure SetPriority(const Value: ToastNotificationPriority);
    function GetExireReboot: boolean;
    procedure SetExpireReboot(const Value: boolean);
    procedure SetEventActivated(const Value: TOnToastActivated);
    procedure SetEventDismissed(const Value: TOnToastDismissed);
    procedure SetEventFailed(const Value: TOnToastFailed);
  public
    // Data read
    property Posted: boolean read FPosted;
    property Hidden: boolean read FHidden;
    function Content: TXMLInterface;
    ///  <summary>
    ///  Defines the time at which the popup will dissapear.
    ///  </summary>
    property ExpirationTime: TDateTime read GetExpiration write SetExpiration;
    ///  <summary>
    ///  Defines wheather the popup is shown to the user on the
    ///  screen or of It's placed directly in the action center.
    ///  </summary>
    property SuppressPopup: boolean read GetSuppress write SetSuppress;

    // Identifier
    property Tag: string read GetTag write SetTag;
    property Group: string read GetGroup write SetGroup;

    // Remote notification
    property NotificationMirroring: NotificationMirroring read GetMirroring write SetMirroring;
    property RemoteId: string read GetRemoteID write SetRemoteID;

    // Data
    property Data: TNotificationData read FData write SetData;

    // Notification priority
    property Priority: ToastNotificationPriority read GetPriority write SetPriority;

    // Expire notification after reboot
    property ExpiresOnReboot: boolean read GetExireReboot write SetExpireReboot;

    // Events
    property OnActivated: TOnToastActivated read FOnActivated write SetEventActivated;
    property OnDismissed: TOnToastDismissed read FOnDismissed write SetEventDismissed;
    property OnFailed: TOnToastFailed read FOnFailed write SetEventFailed;

    // Utils
    /// <summary>
    ///  Reset the notification to It's default state before being posted.
    /// </summary>
    procedure Reset;

    // Constructors
    constructor Create(XMLDocument: TDomXMLDocument);
    destructor Destroy; override;
  end;

  // Builder
  TToastContentBuilder = class
  private
    FXML: TWinXMLDocument;
    FXMLVisual,
    FXMLBinding,
    FXMLActions: TWinXMLNode;

    procedure EnsureActions;

    procedure HandleValues(AValues: TArray<TToastValue>);
  public
    function GenerateXML: TDomXMLDocument; virtual;

    (* Using the generates XML, create a notification *)
    function CreateNotification: TNotification;
    (* Free this object and set the notificaiton *)
    procedure CreateNotificationAndFree(var NotifObject: TNotification);

    // Adders
    function AddText(AText: TToastValue): TToastContentBuilder;
    (* https://learn.microsoft.com/en-us/uwp/schemas/tiles/toastschema/element-audio *)
    function AddAudio(URI: string; Loop: TWinBoolean = TWinBoolean.WinDefault; Silent: TWinBoolean=TWinBoolean.WinDefault): TToastContentBuilder; overload;
    function AddAudio(CustomSound: TSoundEventValue; Loop: TWinBoolean=TWinBoolean.WinDefault; Silent: TWinBoolean=TWinBoolean.WinDefault): TToastContentBuilder; overload;
    (* https://learn.microsoft.com/en-us/uwp/schemas/tiles/toastschema/element-image *)
    function AddHeroImage(URI: TToastValue; AltText: string=''): TToastContentBuilder;
    function AddAppLogoOverride(URI: TToastValue; AdaptiveCrop: TImageCrop; AltText: string=''): TToastContentBuilder;
    function AddInlineImage(URI: TToastValue; AltText: string='';
      AdaptiveCrop: TImageCrop=TImageCrop.Default; RemoveMargin: boolean=false): TToastContentBuilder;
    (* https://learn.microsoft.com/en-us/uwp/schemas/tiles/toastschema/element-progress *)
    function AddProgressBar(Title: TToastValue; Value: TToastValue): TToastContentBuilder; overload;
    function AddProgressBar(Title: TToastValue; Value: TToastValue; Indeterminate: TWinBoolean): TToastContentBuilder; overload;
    function AddProgressBar(Title: TToastValue; Value: TToastValue;
      Indeterminate: TWinBoolean; ValueStringOverride: TToastValue;  Status: TToastValue): TToastContentBuilder; overload;
    (* https://learn.microsoft.com/en-us/uwp/schemas/tiles/toastschema/element-input *)
    function AddInputTextBox(ID: string; Placeholder: string=''; Title: string=''): TToastContentBuilder;
    function AddComboBox(ID: string; Title: string; SelectedItemID: string; Items: TArray<TToastComboItem>): TToastContentBuilder;
    (* https://learn.microsoft.com/en-us/uwp/schemas/tiles/toastschema/element-action *)
    function AddButton(Content: string; ActivationType: TActivationType; Arguments: string): TToastContentBuilder; overload;
    function AddButton(Content: string; ActivationType: TActivationType; Arguments, ImageURI: string): TToastContentBuilder; overload;
    (* https://learn.microsoft.com/en-us/uwp/schemas/tiles/toastschema/element-header *)
    function AddHeader(ID, Title, Arguments: string): TToastContentBuilder;

    (* https://learn.microsoft.com/en-us/dotnet/api/microsoft.toolkit.uwp.notifications.toastcontentbuilder.settoastduration *)
    function SetDuration(Duration: TToastDuration): TToastContentBuilder;

    (* https://learn.microsoft.com/en-us/dotnet/api/microsoft.toolkit.uwp.notifications.toastcontent.scenario *)
    function SetScenario(Scenario: TToastScenario): TToastContentBuilder;

    (* https://learn.microsoft.com/en-us/windows/apps/design/shell/tiles-and-notifications/toast-schema#toastactivationtype *)
    function SetActivationType(const Value: TActivationType): TToastContentBuilder;

    (* The launch URI launched when the notification is clicked, TActivationType. Protocol is required! *)
    function SetLaunchURI(URI: string): TToastContentBuilder;

    // Constructors
    constructor Create;
    destructor Destroy; override;
  end;

  TNotificationManager = class(TObject)
  private
    FNotifier: IToastNotifier;
    FNotifier2: IToastNotifier2; // optional, required for updating

    FRegSettingsPath: string;

    // System
    function HasRegistryRecord: boolean;

    // Notifier
    procedure RebuildNotifier;

    // Getters
    function GetHideLockScreen: TWinBoolean;
    function GetShowBanner: TWinBoolean;
    function GetShowInActionCenter: TWinBoolean;
    function GetRank: TNotificationRank;
    function GetStatusInteractionCount: integer;
    function GetStatusNotificationCount: integer;
    function GetSetting: NotificationSetting;

    // Setters
    procedure SetHideLockScreen(const Value: TWinBoolean);
    procedure SetShowBanner(const Value: TWinBoolean);
    procedure SetShowInActionCenter(const Value: TWinBoolean);
    procedure SetRank(const Value: TNotificationRank);

  public
    // Notificaitons
    procedure ShowNotification(Notification: TNotification);
    procedure HideNotification(Notification: TNotification);

    procedure UpdateNotification(Notification: TNotification);

    // Utils
    procedure DestroyNotification(var ANotification: TNotification); // hide & free notification
    procedure RepostNotification(ANotification: TNotification);

    // Action Center Settings
    property HideOnLockScreen: TWinBoolean read GetHideLockScreen write SetHideLockScreen;
    property ShowBanner: TWinBoolean read GetShowBanner write SetShowBanner;
    property ShowInActionCenter: TWinBoolean read GetShowInActionCenter write SetShowInActionCenter;
    property Rank: TNotificationRank read GetRank write SetRank;

    // Status and telemetry
    property TotalNotificationCount: integer read GetStatusNotificationCount;
    property TotalInteractionCount: integer read GetStatusInteractionCount;
    property Setting: NotificationSetting read GetSetting;

    // Utils
    /// <summary>
    ///  Reset the notification icon to a default icon cache craeted by the app.
    /// </summary>
    procedure CustomAudioMode(AudioMode: TAudioMode; SoundFilePath: string='');
    /// <summary>
    ///  Create all the registry keys
    /// </summary>
    procedure CreateRegistryRecord;
    /// <summary>
    ///  Delete all registry keys containing settings for this app.
    /// </summary>
    procedure DeleteRegistryRecord;

    property P: IToastNotifier read FNotifier;

    // Constructors
    constructor Create;
    destructor Destroy; override;
  end;

// Interface IDs
const
  IID_IToastNotifier2: TGUID = '{354389C6-7C01-4BD5-9C20-604340CD2B74}';
  IID_IToastNotification2: TGUID = '{9DFB9FD1-143A-490E-90BF-B9FBA7132DE7}';
  IID_IToastNotification3: TGUID = '{31E8AED8-8141-4F99-BC0A-C4ED21297D77}';
  IID_IToastNotification4: TGUID = '{15154935-28EA-4727-88E9-C58680E2D118}';
  IID_IToastNotification6: TGUID = '{43EBFE53-89AE-5C1E-A279-3AECFE9B6F54}';
  IID_IScheduledToastNotifier: TGUID = '{79F577F8-0DE7-48CD-9740-9B370490C838}';

implementation

{ TNotificationManager }

constructor TNotificationManager.Create;
begin
  inherited Create;
  // Registration
  if not AppRegistration.RegisteredAny then
    OutputDebugString('WARNING: The application model ID is not registered. Notifications will not display.');

  // Set
  FRegSettingsPath :=
    Format('HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings\%S', [AppRegistration.AppUserModelID]);

  // Build notifier
  RebuildNotifier;
end;

procedure TNotificationManager.CreateRegistryRecord;
begin
  // Create settings
  if not TQuickReg.KeyExists(FRegSettingsPath) then begin
    TQuickReg.CreateKey(FRegSettingsPath);
  end;
end;

procedure TNotificationManager.CustomAudioMode(AudioMode: TAudioMode;
  SoundFilePath: string);
begin
  const VAL = 'SoundFile';

  case AudioMode of
    TAudioMode.Default:
      if TQuickReg.ValueExists(FRegSettingsPath, VAL) then
        TQuickReg.DeleteValue(FRegSettingsPath, VAL);
    TAudioMode.Muted: TQuickReg.WriteValue(FRegSettingsPath, VAL, '');
    TAudioMode.Custom: TQuickReg.WriteValue(FRegSettingsPath, VAL, SoundFilePath);
  end;
end;

procedure TNotificationManager.DeleteRegistryRecord;
begin
  // Delete user configurations
  TQuickReg.DeleteKey(FRegSettingsPath);
end;

destructor TNotificationManager.Destroy;
begin
  FNotifier := nil;
  inherited;
end;

procedure TNotificationManager.DestroyNotification(
  var ANotification: TNotification);
begin
  if ANotification = nil then
    Exit;
  try
    HideNotification( ANotification );
  except
  end;
  FreeAndNil( ANotification );
end;

function TNotificationManager.GetHideLockScreen: TWinBoolean;
begin
  Result := WinDefault;
  const VAL = 'AllowContentAboveLock';

  if TQuickReg.ValueExists(FRegSettingsPath, VAL) then
    Result := TWinBool.Create( TQuickReg.GetBoolValue(FRegSettingsPath, VAL) );
end;

function TNotificationManager.GetRank: TNotificationRank;
begin
  Result := TNotificationRank.Default;
  const VAL = 'ShowInActionCenter';

  if TQuickReg.ValueExists(FRegSettingsPath, VAL) then
    case TQuickReg.GetIntValue(FRegSettingsPath, VAL) of
      0: Result := TNotificationRank.Normal;
      1..98: Result := TNotificationRank.High;
      99..1000: Result := TNotificationRank.Topmost;
    end;
end;

function TNotificationManager.GetShowBanner: TWinBoolean;
begin
  Result := WinDefault;
  const VAL = 'ShowBanner';

  if TQuickReg.ValueExists(FRegSettingsPath, VAL) then
    Result := TWinBool.Create( TQuickReg.GetBoolValue(FRegSettingsPath, VAL) );
end;

function TNotificationManager.GetShowInActionCenter: TWinBoolean;
begin
  Result := WinDefault;
  const VAL = 'ShowInActionCenter';

  if TQuickReg.ValueExists(FRegSettingsPath, VAL) then
    Result := TWinBool.Create( TQuickReg.GetBoolValue(FRegSettingsPath, VAL) );
end;

function TNotificationManager.GetStatusInteractionCount: integer;
begin
  Result := 0;
  const VAL = 'PeriodicInteractionCount';

  if TQuickReg.ValueExists(FRegSettingsPath, VAL) then
    Result := TQuickReg.GetIntValue(FRegSettingsPath, VAL);
end;

function TNotificationManager.GetStatusNotificationCount: integer;
begin
  Result := 0;
  const VAL = 'PeriodicNotificationCount';

  if TQuickReg.ValueExists(FRegSettingsPath, VAL) then
    Result := TQuickReg.GetIntValue(FRegSettingsPath, VAL);
end;

function TNotificationManager.HasRegistryRecord: boolean;
begin
  Result := TQuickReg.KeyExists(FRegSettingsPath);
end;

procedure TNotificationManager.HideNotification(Notification: TNotification);
begin
  if not Notification.Posted then
    raise EWinRTNotificationNotVisible.Create('Notification is not visible.');

  FNotifier.Hide(Notification.FToast);

  // Status
  Notification.FHidden := true;
end;

procedure TNotificationManager.RebuildNotifier;
var
  AName: HSTRING;
begin                                         
  FNotifier := nil;
  FNotifier2 := nil;
                        
  // Create IToastInterface
  AName := HString.Create( AppRegistration.AppUserModelID );
  try
    try
      FNotifier := TToastNotificationManager.CreateToastNotifier(AName);
    except
      raise EWinRTNotificationCreationFailed.Create('Failed to create notification toast.');
    end;
  finally
    AName.Free;
  end;
          
  // Query IToastInterace2
  if Supports(FNotifier, IToastNotifier2, FNotifier2) then
    FNotifier.QueryInterface(IID_IToastNotifier2, FNotifier2);
end;

procedure TNotificationManager.RepostNotification(ANotification: TNotification);
begin
  if ANotification = nil then
    Exit;
  try
    HideNotification( ANotification );
  except
  end;

  // Make new toast
  ANotification.Reset;

  // Post
  ShowNotification( ANotification );
end;

procedure TNotificationManager.SetShowBanner(const Value: TWinBoolean);
begin
  const VAL = 'ShowBanner';

  if Value <> WinDefault then
    TQuickReg.WriteValue(FRegSettingsPath, VAL, Value.ToBoolean())
  else
    if TQuickReg.ValueExists(FRegSettingsPath, VAL) then
      TQuickReg.DeleteValue(FRegSettingsPath, VAL);
end;

procedure TNotificationManager.SetShowInActionCenter(const Value: TWinBoolean);
begin
  const VAL = 'ShowInActionCenter';

  if Value <> WinDefault then
    TQuickReg.WriteValue(FRegSettingsPath, VAL, Value.ToBoolean())
  else
    if TQuickReg.ValueExists(FRegSettingsPath, VAL) then
      TQuickReg.DeleteValue(FRegSettingsPath, VAL);
end;

procedure TNotificationManager.SetHideLockScreen(const Value: TWinBoolean);
begin
  const VAL = 'AllowContentAboveLock';

  if Value <> WinDefault then
    TQuickReg.WriteValue(FRegSettingsPath, VAL, Value.ToBoolean())
  else
    if TQuickReg.ValueExists(FRegSettingsPath, VAL) then
      TQuickReg.DeleteValue(FRegSettingsPath, VAL);
end;

procedure TNotificationManager.SetRank(const Value: TNotificationRank);
begin
  const VAL = 'ShowInActionCenter';

  case Value of
    TNotificationRank.Default:
      if TQuickReg.ValueExists(FRegSettingsPath, VAL) then
        TQuickReg.DeleteValue(FRegSettingsPath, VAL);
    TNotificationRank.Normal: TQuickReg.WriteValue(FRegSettingsPath, VAL, 0);
    TNotificationRank.High: TQuickReg.WriteValue(FRegSettingsPath, VAL, 1);
    TNotificationRank.Topmost: TQuickReg.WriteValue(FRegSettingsPath, VAL, 99);
  end;
end;

procedure TNotificationManager.ShowNotification(Notification: TNotification);
begin
  if Notification.Posted then
    raise EWinRTNotificationAlreadyPosted.Create('Notification has already been posted.');

  // Register
  if not HasRegistryRecord then
    CreateRegistryRecord;

  // Show
  FNotifier.Show(Notification.FToast);

  // Status
  Notification.FPosted := true;
end;

procedure TNotificationManager.UpdateNotification(Notification: TNotification);
var
  Data: TNotificationData;
  HS_Tag, HS_Group: HSTRING;
begin
  if not Notification.Posted then
    raise EWinRTNotificationNotActive.Create('Notification is not active.');

  if Notification.Tag = '' then
    raise EWinRTNotificationNoTag.Create('Tag is required to update notification.');

  if FNotifier2 = nil then
    raise EWinRTNotificationFeatureNotSupported.Create('This device does not support updating notifications.');

  // Get data
  Data := Notification.Data;

  // Update
  HS_Tag := StringToHString(Notification.Tag);
  HS_Group := StringToHString(Notification.Group);

  try             
    var Result: NotificationUpdateResult;
    if Notification.Group = '' then
      Result := FNotifier2.Update(Data.Data, HS_Tag)
    else
      Result := FNotifier2.Update(Data.Data, HS_Tag, HS_Group);

    case Result of
      NotificationUpdateResult.Failed: raise EWinRTNotificationUpdateFailed.Create('Update procedure for notification has failed.');
      NotificationUpdateResult.NotificationNotFound: raise EWinRTNotificationNotificationNotFound.Create('Update procedure for notification failed, notification not found');
    end;
  finally
    FreeHString(HS_Tag);
    FreeHString(HS_Group);
  end;
end;

{ TNotificationActivatedHandler }

procedure TNotificationActivatedHandler.Invoke(sender: IToastNotification;
  args: IInspectable);
begin
  const Data = args as IToastActivatedEventArgs;
  const Data2 = args as IToastActivatedEventArgs2;

  const Map = TUserInputMap.Create(Data2.UserInput as IMap_2__HSTRING__IInspectable);
  try
    FNotification.FOnActivated(FNotification, Data.Arguments.ToString, Map);
  finally
    // Free instance
    Map.Free;
  end;
end;

procedure TNotificationActivatedHandler.Subscribe;
begin
  FToken := FNotification.FToast.add_Activated( Self );
end;

procedure TNotificationActivatedHandler.Unsubscribe;
begin
  FNotification.FToast.remove_Activated( FToken );
  inherited;
end;

{ TNotificationDismissedHandler }

procedure TNotificationDismissedHandler.Invoke(sender: IToastNotification;
  args: IToastDismissedEventArgs);
begin
  FNotification.FOnDismissed(FNotification, args.Reason);
end;

procedure TNotificationDismissedHandler.Subscribe;
begin
  FToken := FNotification.FToast.add_Dismissed( Self );
end;

procedure TNotificationDismissedHandler.Unsubscribe;
begin
  FNotification.FToast.remove_Dismissed( FToken );
  inherited;
end;

{ TNotificationFailedHandler }

procedure TNotificationFailedHandler.Invoke(sender: IToastNotification;
  args: IToastFailedEventArgs);
begin
  FNotification.FOnFailed(FNotification, args.ErrorCode);
end;

procedure TNotificationFailedHandler.Subscribe;
begin
  FToken := FNotification.FToast.add_Failed( Self );
end;

procedure TNotificationFailedHandler.Unsubscribe;
begin
  FNotification.FToast.remove_Dismissed( FToken );
  inherited;
end;

{ TToastStringValue }

constructor TToastValueString.Create(AValue: string);
begin
  Value := AValue;
end;

function TToastValueString.ToXML: string;
begin
  Result := Value;
end;

{ TNotificationBindableValue }

function TToastValueBindable.ToXML: string;
begin
  Result := Format('{%S}', [Value]);
end;

{ TToastContentBuilder }

function TToastContentBuilder.AddAudio(URI: string; Loop, Silent: TWinBoolean): TToastContentBuilder;
begin
  with FXML.Nodes.AddNode('audio') do begin
    Attributes['src'] := URI;

    if Loop <> TWinBoolean.WinDefault then
      Attributes['loop'] := Loop.ToString;
    if Silent <> TWinBoolean.WinDefault then
      Attributes['silent'] := Silent.ToString;
  end;

  //
  Result := Self;
end;

function TToastContentBuilder.AddAppLogoOverride(URI: TToastValue;
  AdaptiveCrop: TImageCrop; AltText: string): TToastContentBuilder;
begin
  with FXMLBinding.Nodes.AddNode('image') do begin
    Attributes['src'] := URI.ToXML;
    Attributes['placement'] := 'appLogoOverride';

    case AdaptiveCrop of
      TImageCrop.None: Attributes['hint-crop'] := 'none';
      TImageCrop.Circle: Attributes['hint-crop'] := 'circle';
    end;
    
    Attributes['alt'] := AltText;
  end;

  HandleValues([URI]);

  //
  Result := Self;
end;

function TToastContentBuilder.AddAudio(CustomSound: TSoundEventValue; Loop,
  Silent: TWinBoolean): TToastContentBuilder;
begin
  AddAudio(CustomSound.ToString, Loop, Silent);

  //
  Result := Self;
end;

function TToastContentBuilder.AddButton(Content: string;
  ActivationType: TActivationType; Arguments, ImageURI: string): TToastContentBuilder;
begin
  EnsureActions;
  
  with FXMLActions.Nodes.AddNode('action') do begin
    Attributes['content'] := Content;
    Attributes['arguments'] := Arguments;

    const sActType = ActivationType.ToString;
    if sActType <> '' then
      Attributes['activationType'] := sActType;

    if ImageURI <> '' then
      Attributes['imageUri'] := ImageURI;
  end;

  //
  Result := Self;
end;

function TToastContentBuilder.AddComboBox(ID: string; Title: string;
  SelectedItemID: string; Items: TArray<TToastComboItem>): TToastContentBuilder;
begin
  EnsureActions;
  
  with FXMLActions.Nodes.AddNode('input') do begin    
    Attributes['id'] := ID;
    Attributes['type'] := 'selection';
    Attributes['title'] := Title;
    Attributes['defaultInput'] := SelectedItemID;
    
    for var I := 0 to High(Items) do
      with Nodes.AddNode('selection') do begin
        Attributes['id'] := Items[I].ID;
        Attributes['content'] := Items[I].Content;
      end;
  end;

  //
  Result := Self;
end;

function TToastContentBuilder.AddButton(Content: string;
  ActivationType: TActivationType; Arguments: string): TToastContentBuilder;
begin
  AddButton(Content, ActivationType, Arguments, '');

  //
  Result := Self;
end;

function TToastContentBuilder.AddHeader(ID, Title, Arguments: string): TToastContentBuilder;
begin
  with FXML.Nodes.AddNode('header') do begin
    Attributes['id'] := ID;
    Attributes['title'] := Title;
    Attributes['arguments'] := Arguments;
  end;

  //
  Result := Self;
end;

function TToastContentBuilder.AddHeroImage(URI: TToastValue; AltText: string): TToastContentBuilder;
begin
  with FXMLBinding.Nodes.AddNode('image') do begin
    Attributes['src'] := URI.ToXML;
    Attributes['placement'] := 'hero';
    
    Attributes['alt'] := AltText;
  end;

  HandleValues([URI]);

  //
  Result := Self;
end;

function TToastContentBuilder.AddInlineImage(URI: TToastValue; AltText: string;
  AdaptiveCrop: TImageCrop; RemoveMargin: boolean): TToastContentBuilder;
begin
  with FXMLBinding.Nodes.AddNode('image') do begin
    Attributes['src'] := URI.ToXML;

    case AdaptiveCrop of
      TImageCrop.None: Attributes['hint-crop'] := 'none';
      TImageCrop.Circle: Attributes['hint-crop'] := 'circle';
    end;
    
    Attributes['alt'] := AltText;
  end;

  HandleValues([URI]);

  //
  Result := Self;
end;

function TToastContentBuilder.AddInputTextBox(ID, Placeholder, Title: string): TToastContentBuilder;
begin
  EnsureActions;

  with FXMLActions.Nodes.AddNode('input') do begin
    Attributes['id'] := ID;
    Attributes['type'] := 'text';
    Attributes['title'] := Title;
    Attributes['placeHolderContent'] := Placeholder;
  end;

  //
  Result := Self;
end;

function TToastContentBuilder.AddProgressBar(Title, Value: TToastValue;
  Indeterminate: TWinBoolean): TToastContentBuilder;
begin
  AddProgressBar(Title, Value, Indeterminate, TToastValueString.Create(''),
    TToastValueString.Create(''));

  Result := Self;
end;

function TToastContentBuilder.AddProgressBar(Title, Value: TToastValue;
  Indeterminate: TWinBoolean; ValueStringOverride, Status: TToastValue): TToastContentBuilder;
begin
  with FXMLBinding.Nodes.AddNode('progress') do begin
    case Indeterminate of
      WinTrue: Attributes['value'] := 'indeterminate';
      else Attributes['value'] := Value.ToXML;
    end;
    
    Attributes['title'] := Title.ToXML;
    const S = ValueStringOverride.ToXML;
    if S <> '' then
      Attributes['valueStringOverride'] := ValueStringOverride.ToXML;
    Attributes['status'] := Status.ToXML;
  end;

  HandleValues([Title, Value, ValueStringOverride, Status]);

  //
  Result := Self;
end;

function TToastContentBuilder.AddProgressBar(Title, Value: TToastValue): TToastContentBuilder;
begin
  AddProgressBar(Title, Value, WinFalse, TToastValueString.Create(''),
    TToastValueString.Create(''));

  //
  Result := Self;
end;

function TToastContentBuilder.AddText(AText: TToastValue): TToastContentBuilder;
begin
  FXMLBinding.Nodes.AddNode('text').Contents := AText.ToXML;

  HandleValues([AText]);

  //
  Result := Self;
end;

constructor TToastContentBuilder.Create;
begin
  FXML := TWinXMLDocument.Create;
  FXML.TagName := 'toast';

  FXMLVisual := FXML.Nodes.AddNode('visual');
  FXMLBinding:= FXMLVisual.Nodes.AddNode('binding');
  FXMLBinding.Attributes['template']:='ToastGeneric';
end;

destructor TToastContentBuilder.Destroy;
begin
  FXML.Free;
  inherited;
end;

procedure TToastContentBuilder.EnsureActions;
begin
  if FXMLActions = nil then
    FXMLActions:= FXML.Nodes.AddNode('actions');
end;

function TToastContentBuilder.CreateNotification: TNotification;
begin
  Result := TNotification.Create( GenerateXML );
end;

procedure TToastContentBuilder.CreateNotificationAndFree(var NotifObject: TNotification);
begin
  NotifObject := CreateNotification;

  // Free object
  Self.Free;
end;

function TToastContentBuilder.GenerateXML: TDomXMLDocument;
begin
  Result := TDomXMLDocument.Create;
  const XML = FXML.OuterXML;

  Result.Parse( XML );
end;

procedure TToastContentBuilder.HandleValues(AValues: TArray<TToastValue>);
begin
  for var I := 0 to High(AValues) do begin
    // Free memory
    AValues[I].Free;
  end;
end;

function TToastContentBuilder.SetActivationType(
  const Value: TActivationType): TToastContentBuilder;
begin
  if Value = TActivationType.Default then
    FXML.Attributes.DeleteAttribute('activationType')
  else
    FXML.Attributes['activationType'] := Value.ToString;

  //
  Result := Self;
end;

function TToastContentBuilder.SetLaunchURI(URI: string): TToastContentBuilder;
begin
  FXML.Attributes['launch'] := URI;

  //
  Result := Self;
end;

function TToastContentBuilder.SetDuration(Duration: TToastDuration): TToastContentBuilder;
const
  ATTR = 'duration';
begin
  if Duration = TToastDuration.Default then
    FXML.Attributes.DeleteAttribute(ATTR)
  else
    FXML.Attributes[ATTR] := Duration.ToString;

  //
  Result := Self;
end;

function TToastContentBuilder.SetScenario(Scenario: TToastScenario): TToastContentBuilder;
const
  ATTR = 'scenario';
begin
  if Scenario = TToastScenario.Default then
    FXML.Attributes.DeleteAttribute(ATTR)
  else
    FXML.Attributes[ATTR] := Scenario.ToString;

  Result := Self;
end;

{ TNotification }

function TNotification.Content: TXMLInterface;
begin
  Result := FToast.Content;
end;

constructor TNotification.Create(XMLDocument: TDomXMLDocument);
begin
  Initiate( XMLDocument.DomXML );

  FHidden := false;
  FPosted := false;
end;

destructor TNotification.Destroy;
begin
  // Free and unsubscribe events
  FreeEvents;

  // Free runtime data object
  FData.Free;

  // Set interfaces to nill
  FToast := nil;
  FToast2 := nil;
  FToast3 := nil;
  FToast4 := nil;
  FToast6 := nil;

  inherited;
end;

procedure TNotification.FreeEvents;
begin
  ///  These elements are NOT freed since they use the refrence count system,
  ///  which in turn means when they are no longer used, they are freed
  ///  automatically.

  if FHandleActivated <> nil then
    FHandleActivated.Unsubscribe;
  if FHandleDismissed <> nil then
    FHandleDismissed.Unsubscribe;
  if FHandleFailed <> nil then
    FHandleFailed.Unsubscribe;
end;

function TNotification.GetExireReboot: boolean;
begin
  Result := FToast6.ExpiresOnReboot;
end;

function TNotification.GetExpiration: TDateTime;
begin
  Result := DateTimeToTDateTime( FToast.ExpirationTime.Value );
end;

function TNotification.GetGroup: string;
begin
  const HStr = FToast2.Group;
  Result := HStr.ToString;
  HStr.Free;
end;

function TNotification.GetMirroring: NotificationMirroring;
begin
  Result := FToast3.NotificationMirroring_;
end;

function TNotification.GetPriority: ToastNotificationPriority;
begin
  Result := FToast4.Priority;
end;

function TNotification.GetRemoteID: string;
begin
  const HStr = FToast3.RemoteId;
  Result := HStr.ToString;
  HStr.Free;
end;

function TNotification.GetSuppress: boolean;
begin
  Result := FToast2.SuppressPopup;
end;

function TNotification.GetTag: string;
begin
  const HStr = FToast2.Tag;
  Result := HStr.ToString;
  HStr.Free;
end;

procedure TNotification.Initiate(XML: TXMLInterface);
begin
  FToast := TToastNotification.CreateToastNotification( XML );

  if Supports(FToast, IID_IToastNotification2) then
    FToast.QueryInterface(IID_IToastNotification2, FToast2);
  if Supports(FToast, IID_IToastNotification3) then
    FToast.QueryInterface(IID_IToastNotification3, FToast3);
  if Supports(FToast, IID_IToastNotification4) then
    FToast.QueryInterface(IID_IToastNotification4, FToast4);
  if Supports(FToast, IID_IToastNotification6) then
    FToast.QueryInterface(IID_IToastNotification6, FToast6);

  if Supports(FToast, IID_IScheduledToastNotifier) then
    FToast.QueryInterface(IID_IScheduledToastNotifier, FToastScheduled);
end;

procedure TNotification.Reset;
begin
  const PrevToast = FToast;
  const PrevToast2 = FToast2;
  const PrevToast3 = FToast2;
  const PrevToast4 = FToast2;
  const PrevToast6 = FToast2;

  // Clear
  FHidden := false;
  FPosted := false;

  FToast := nil;
  FToast2 := nil;
  FToast3 := nil;
  FToast4 := nil;
  FToast6 := nil;

  // Create
  Initiate( prevToast.Content );

  FToast.ExpirationTime := prevToast.ExpirationTime;
  if not PrevToast2.Tag.Empty then
    FToast2.Tag := PrevToast2.Tag;
  if not PrevToast2.Group.Empty then
    FToast2.Group := PrevToast2.Group;
  FToast2.SuppressPopup := PrevToast2.SuppressPopup;
  FToast3.NotificationMirroring_ := FToast3.NotificationMirroring_;
  if not FToast3.RemoteId.Empty then
    FToast3.RemoteId := FToast3.RemoteId;
  FToast4.Priority := FToast4.Priority;
  FToast6.ExpiresOnReboot := FToast6.ExpiresOnReboot;

  // Reset data
  FToast4.Data := FData.Data;

  // Re-subscribe to events
  if FHandleActivated <> nil then
    FHandleActivated.Resubscribe;
  if FHandleDismissed <> nil then
    FHandleDismissed.Resubscribe;
  if FHandleFailed <> nil then
    FHandleFailed.Resubscribe;
end;

procedure TNotification.SetData(const Value: TNotificationData);
begin
  FData := Value;
  FToast4.Data := Value.Data;
end;

procedure TNotification.SetEventActivated(const Value: TOnToastActivated);
begin
  FOnActivated := Value;

  // Register status
  if (FHandleActivated <> nil) <> (@Value <> nil) then
    if FHandleActivated <> nil then
      FreeAndNil(FHandleActivated)
    else
      FHandleActivated := TNotificationActivatedHandler.Create(Self);
end;

procedure TNotification.SetEventDismissed(const Value: TOnToastDismissed);
begin
  FOnDismissed := Value;

  // Register status
  if (FHandleDismissed <> nil) <> (@Value <> nil) then
    if FHandleDismissed <> nil then
      FreeAndNil(FHandleDismissed)
    else
      FHandleDismissed := TNotificationDismissedHandler.Create(Self);
end;

procedure TNotification.SetEventFailed(const Value: TOnToastFailed);
begin
  FOnFailed := Value;

  // Register status
  if (FHandleFailed <> nil) <> (@Value <> nil) then
    if FHandleFailed <> nil then
      FreeAndNil(FHandleFailed)
    else
      FHandleFailed := TNotificationFailedHandler.Create(Self);
end;

procedure TNotification.SetExpiration(const Value: TDateTime);
var
  Reference: IReference_1__DateTime;
begin
  // Create a new instance of IReference_1__DateTime
  TPropertyValue.CreateDateTime(
    TDateTimeToDateTime(Value)
  ).QueryInterface(IReference_1__DateTime, Reference);

  // Now you can assign this reference to ExpirationTime
  FToast.ExpirationTime := Reference;
end;

procedure TNotification.SetExpireReboot(const Value: boolean);
begin
  FToast6.ExpiresOnReboot := Value;
end;

procedure TNotification.SetGroup(const Value: string);
begin
  const HStr = HString.Create(Value);
  FToast2.Group;
  HStr.Free;
end;

procedure TNotification.SetMirroring(const Value: NotificationMirroring);
begin
  FToast3.NotificationMirroring_ := Value;    
end;

procedure TNotification.SetPriority(
  const Value: ToastNotificationPriority);
begin
  FToast4.Priority := Value;;
end;

procedure TNotification.SetRemoteID(const Value: string);
begin
  const HStr = HString.Create(Value);
  FToast3.RemoteId := HStr;
  HStr.Free;
end;

procedure TNotification.SetSuppress(const Value: boolean);
begin
  FToast2.SuppressPopup := Value;
end;

procedure TNotification.SetTag(const Value: string);
begin
  const HStr = HString.Create(Value);
  FToast2.Tag := HStr;
  HStr.Free;
end;

{ TNotificationData }

procedure TNotificationData.Clear;
begin
  Data.Values.Clear;
end;

constructor TNotificationData.Create;
begin
  // Runtime class
  Data := TInstanceFactory.CreateNamed<INotificationData>('Windows.UI.Notifications.NotificationData');
end;

procedure TNotificationData.DeleteValue(Key: string);
begin
  const HKey = HString.Create(Key);
  try
    if Data.Values.HasKey(HKey) then
      Data.Values.Remove(HKey);
  finally
    HKey.Free;
  end;
end;

destructor TNotificationData.Destroy;
begin
  Data := nil;
  inherited;
end;

function TNotificationData.GetSeq: cardinal;
begin
  Result := Data.SequenceNumber;
end;

function TNotificationData.GetValue(Key: string): string;
begin
  const HKey = HString.Create(Key);
  try
    if Data.Values.HasKey(HKey) then begin
      const HData = Data.Values.Lookup(HKey);
      try
        Result := HData.ToString;
      finally
        HData.Free;
      end;
    end;
  finally
    HKey.Free;
  end;
end;

procedure TNotificationData.IncreaseSequence;
begin
  SequenceNumber := SequenceNumber + 1;
end;

procedure TNotificationData.SetSeq(const Value: cardinal);
begin
  Data.SequenceNumber := Value;
end;

procedure TNotificationData.SetValue(Key: string; const Value: string);
begin
  const HKey = HString.Create(Key);
  const HData = HString.Create(Value);
  try
    if Data.Values.HasKey(HKey) then 
      Data.Values.Remove(HKey);

    Data.Values.Insert(HKey, HData);
  finally
    HKey.Free;
    HData.Free;
  end;
end;

function TNotificationData.ValueCount: cardinal;
begin
  Result := Data.Values.Size;
end;

function TNotificationData.ValueExists(Key: string): boolean;
begin
  const HStr = HString.Create(Key);
  try
    Result := Data.Values.HasKey(HStr);
  finally
    HStr.Free;
  end;
end;

{ TToastValueSingle }

constructor TToastValueSingle.Create(AValue: single);
begin
  Value := AValue;
end;

function TToastValueSingle.ToXML: string;
begin
  Result := Value.ToString;
end;

{ TNotificationEventHandler }

constructor TNotificationEventHandler.Create(
  const ANotification: TNotification);
begin
  FNotification := ANotification;
  FToken.Value := -1;

  // Subscribe
  Subscribe;
end;

destructor TNotificationEventHandler.Destroy;
begin
  // Unsubscribe
  if Subscribed then
    Unsubscribe;

  // Set to nil
  FNotification := nil;

  inherited;
end;

function TNotificationEventHandler.GetSubscribed: boolean;
begin
  Result := FToken.Value <> -1;
end;

procedure TNotificationEventHandler.Resubscribe;
begin
  Unsubscribe;

  Subscribe;
end;

procedure TNotificationEventHandler.Unsubscribe;
begin
  // code

  // inheritable
  FToken.Value := -1;
end;

{ TUserInputMap }

constructor TUserInputMap.Create(LookupMap: IMap_2__HSTRING__IInspectable);
begin
  FMap := LookupMap;
end;

destructor TUserInputMap.Destroy;
begin
  FMap := nil;
end;

function TUserInputMap.GetIntValue(ID: string): integer;
begin
  const HStr = HString.Create(ID);
  try
    Result:= (FMap.Lookup( HStr ) as IPropertyValue).GetInt32;
  finally
    HStr.Free;
  end;
end;

function TUserInputMap.GetStringValue(ID: string): string;
begin
  const HStr = HString.Create(ID);
  try
    const HRes = (FMap.Lookup( HStr ) as IPropertyValue).GetString;
    try
      Result := HRes.ToString;
    finally
      HRes.Free;
    end;
  finally
    HStr.Free;
  end;
end;

function TUserInputMap.HasValue(ID: string): boolean;
begin
  const HStr = HString.Create(ID);
  try
    Result := FMap.HasKey( HStr );
  finally
    HStr.Free;
  end;
end;

{ TSoundEventValueHelper }

function TSoundEventValueHelper.ToString: string;
begin
  case Self of
    TSoundEventValue.Default: Exit( '');
    TSoundEventValue.NotificationDefault: Exit( 'ms-winsoundevent:Notification.Default');
    TSoundEventValue.NotificationIM: Exit('ms-winsoundevent:Notification.IM');
    TSoundEventValue.NotificationMail: Exit('ms-winsoundevent:Notification.Mail');
    TSoundEventValue.NotificationReminder: Exit('ms-winsoundevent:Notification.Reminder');
    TSoundEventValue.NotificationSMS: Exit('ms-winsoundevent:Notification.SMS');
    TSoundEventValue.NotificationLoopingAlarm: Exit('ms-winsoundevent:Notification.Looping.Alarm');
    TSoundEventValue.NotificationLoopingAlarm2: Exit('ms-winsoundevent:Notification.Looping.Alarm2');
    TSoundEventValue.NotificationLoopingAlarm3: Exit('ms-winsoundevent:Notification.Looping.Alarm3');
    TSoundEventValue.NotificationLoopingAlarm4: Exit('ms-winsoundevent:Notification.Looping.Alarm4');
    TSoundEventValue.NotificationLoopingAlarm5: Exit('ms-winsoundevent:Notification.Looping.Alarm5');
    TSoundEventValue.NotificationLoopingAlarm6: Exit('ms-winsoundevent:Notification.Looping.Alarm6');
    TSoundEventValue.NotificationLoopingAlarm7: Exit('ms-winsoundevent:Notification.Looping.Alarm7');
    TSoundEventValue.NotificationLoopingAlarm8: Exit('ms-winsoundevent:Notification.Looping.Alarm8');
    TSoundEventValue.NotificationLoopingAlarm9: Exit('ms-winsoundevent:Notification.Looping.Alarm9');
    TSoundEventValue.NotificationLoopingAlarm10: Exit('ms-winsoundevent:Notification.Looping.Alarm10');
    TSoundEventValue.NotificationLoopingCall: Exit('ms-winsoundevent:Notification.Looping.Call');
    TSoundEventValue.NotificationLoopingCall2: Exit('ms-winsoundevent:Notification.Looping.Call2');
    TSoundEventValue.NotificationLoopingCall3: Exit('ms-winsoundevent:Notification.Looping.Call3');
    TSoundEventValue.NotificationLoopingCall4: Exit('ms-winsoundevent:Notification.Looping.Call4');
    TSoundEventValue.NotificationLoopingCall5: Exit('ms-winsoundevent:Notification.Looping.Call5');
    TSoundEventValue.NotificationLoopingCall6: Exit('ms-winsoundevent:Notification.Looping.Call6');
    TSoundEventValue.NotificationLoopingCall7: Exit('ms-winsoundevent:Notification.Looping.Call7');
    TSoundEventValue.NotificationLoopingCall8: Exit('ms-winsoundevent:Notification.Looping.Call8');
    TSoundEventValue.NotificationLoopingCall9: Exit('ms-winsoundevent:Notification.Looping.Call9');
    TSoundEventValue.NotificationLoopingCall10: Exit('ms-winsoundevent:Notification.Looping.Call10');

    else raise ENotificationUnknownCardinal.Create(ssNotificationUnknownCardinalValue);
  end;
end;

{ TActivationTypeHelper }

function TActivationTypeHelper.ToString: string;
begin
  case Self of
    TActivationType.Default: Exit('');
    TActivationType.Foreground: Exit('foreground');
    TActivationType.Background: Exit('background');
    TActivationType.Protocol: Exit('protocol');
    TActivationType.System: Exit('system');

    else raise ENotificationUnknownCardinal.Create(ssNotificationUnknownCardinalValue);
  end;
end;

{ TToastDurationHelper }

function TToastDurationHelper.ToString: string;
begin
  case Self of
    TToastDuration.Default: Exit('');
    TToastDuration.Short: Exit('short');
    TToastDuration.Long: Exit('long');

    else raise ENotificationUnknownCardinal.Create(ssNotificationUnknownCardinalValue);
  end;
end;

{ TToastScenarioHelper }

function TToastScenarioHelper.ToString: string;
begin
  case Self of
    TToastScenario.Default: Exit('');
    TToastScenario.Alarm: Exit('alarm');
    TToastScenario.Reminder: Exit('reminder');
    TToastScenario.IncomingCall: Exit('incomingCall');
    TToastScenario.Urgent: Exit('urgent');

    else raise ENotificationUnknownCardinal.Create(ssNotificationUnknownCardinalValue);
  end;
end;

end.
