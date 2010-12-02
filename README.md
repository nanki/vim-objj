#Vim Objective-J plugin.

##Install

    $ git clone git://github.com/nanki/vim-objj
    $ vi .vimrc
    set runtimepath+=path/to/objjvim
    au BufNewFile,BufRead *.j,Jakefile setf objj

##Demo
  Checkout Youtube movie that shows the plugin in action.

  [YouTube - Objective-J Completion in Vim](http://www.youtube.com/watch?v=lJrOcHxq6vc)

##Requirements
* Vim compiled with Ruby.
* neocomplcache or AutoComplePop (optional)

##Features

###Smartbrackets
If you type unmatched `]`,

    [CPButton alloc] ]

Smartbrackets will add `[` before `[` which matches the last `]`
and move the cursor before `]` which you typed. (indicated with `^` below)

    [[CPButton alloc] ]
                      ^

In another case, if you type `]` after an Objective-J method,

    [CPButton alloc] init]

Smartbrackets will add a bracket and move the cursor just after the letter you typed then.

    [[CPButton alloc] init]
                           ^

###Omni-completion
By typing C-x C-o, you can use omni-completion anywhere you should input class names, methods and constants.
The plugin provides an Objective-J omni-completion according to precalculated class databases(\*.jd files).  
By default, the repository includes the databases for Foundation.framework and AppKit.framework

The plugin complete class name, class methods and instance methods at the positions indicated below.

    var button = [CPB
                     ^
    var button = [CPButton al
                             ^
    var button = [CPButton alloc] in
                                    ^
    var button = [[CPButton alloc] init];

###Type estimation
When the receiver is not a class name, type estimation will be taking place.

    var button = [CPButton alloc] in

*vim* : Um... `[CPButton alloc]` seems to return (id), maybe (CPButton).


Here are various types of estimation.

####Arguments

    - (void)setWindow:(CPWindow)window {
      [window setFra
                    ^

*vim* : Hmm... window should be an instance of CPWindow.

####Variable Assignment

    var button = [[CPButton alloc] init];
    [button
            ^

*vim* : Mmm... button may be an instance of CPButton.

####self and super
Estimates types from type declarations.

    @implementation CPCustomWindow: CPWindow {
      ...

      [self cont
                ^

*vim* : self should be an instance of CPCustomWindow...

##Links
* [nanki's vim-objj at master - GitHub](http://github.com/nanki/vim-objj)
* [YouTube - Objective-J Completion in Vim](http://www.youtube.com/watch?v=lJrOcHxq6vc)
