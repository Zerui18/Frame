#import "ZX2ChooseVideoViewController.h"

@implementation ZX2ChooseVideoViewController

  - (void) viewDidLoad {
    [super viewDidLoad];

    [self initUI];
    [self setupLayout];
  }

  - (void) viewWillAppear: (bool) animated {
    [super viewWillAppear: animated];
    [self loadPreviews];
  }

  - (void) initUI {
    lockscreenLabel = [[UILabel alloc] init];
    homescreenLabel = [[UILabel alloc] init];

    lockscreenPreview = [[ZX2HookedView alloc] init];
    homescreenPreview = [[ZX2HookedView alloc] init];

    showWallpaperStoreButton = [[UIButton alloc] initWithType: UIButtonTypeCustom];
  }

  - (void) setupLayout {

  }


@end