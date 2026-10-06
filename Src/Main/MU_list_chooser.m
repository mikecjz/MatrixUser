% MatrixUser, a multi-dimensional matrix analysis software package
% https://sourceforge.net/projects/matrixuser/
% 
% The MatrixUser is a matrix analysis software package developed under Matlab
% Graphical User Interface Developing Environment (GUIDE). It features 
% functions that are designed and optimized for working with multi-dimensional
% matrix under Matlab. These functions typically includes functions for 
% multi-dimensional matrix display, matrix (image stack) analysis and matrix 
% processing.
%
% Author:
%   Fang Liu <leoliuf@gmail.com>
%   University of Wisconsin-Madison
%   Aug-30-2014
% _________________________________________________________________________
% Copyright (c) 2011-2014, Fang Liu <leoliuf@gmail.com>
% All rights reserved.
% 
% Redistribution and use in source and binary forms, with or without 
% modification, are permitted provided that the following conditions are 
% met:
% 
%     * Redistributions of source code must retain the above copyright 
%       notice, this list of conditions and the following disclaimer.
%     * Redistributions in binary form must reproduce the above copyright 
%       notice, this list of conditions and the following disclaimer in 
%       the documentation and/or other materials provided with the distribution
%       
% THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" 
% AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE 
% IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE 
% ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE 
% LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
% CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF 
% SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS 
% INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN 
% CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) 
% ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE 
% POSSIBILITY OF SUCH DAMAGE.
% _________________________________________________________________________

% MU_list_chooser shows the entries of a popupmenu uicontrol in a separate
% list window placed just below the control.
%
% The drop-down list of a popupmenu is drawn inside its parent figure and is
% therefore clipped to the figure height, which is a problem for the short
% MatrixUser main window. A separate window is sized to the number of entries
% (up to the screen height) and can extend beyond the main window.
%
%   MU_list_chooser(hPopup, selectFcn)
%       opens the list for popupmenu hPopup (toggles it closed when it is
%       already open). selectFcn(index) is called when an entry is picked.
%   MU_list_chooser('close', hPopup)
%       closes the list window of hPopup if one is open.

function MU_list_chooser(hPopup, selectFcn)

% Close request
if (ischar(hPopup) || isstring(hPopup)) && strcmp(hPopup,'close')
    closeChooser(selectFcn);
    return;
end

% Toggle: a click while the list is open closes it
if closeChooser(hPopup)
    return;
end

% Ignore clicks that arrive while a list window is still being built (the
% drawnow below processes queued mouse events), so only one window exists
if isappdata(hPopup,'MU_list_chooser_busy')
    return;
end
setappdata(hPopup,'MU_list_chooser_busy',true);
busyGuard=onCleanup(@()clearBusy(hPopup));

hParent=ancestor(hPopup,'figure');
contents=get(hPopup,'String');
if ischar(contents)
    contents=cellstr(contents);
end
if isempty(contents)
    return;
end
nItems=numel(contents);
value=max(1,min(get(hPopup,'Value'),nItems));

% Screen position (pixels) of the control
oldUnits=get(hParent,'Units');
set(hParent,'Units','pixels');
figPos=get(hParent,'Position');
set(hParent,'Units',oldUnits);
ctrlPos=getpixelposition(hPopup,true);
ctrlLeft=figPos(1)+ctrlPos(1);
ctrlBottom=figPos(2)+ctrlPos(2);
ctrlTop=ctrlBottom+ctrlPos(4);
scr=get(0,'ScreenSize');

hFig=figure('Visible','off',...
            'MenuBar','none',...
            'ToolBar','none',...
            'NumberTitle','off',...
            'Name','Select matrix',...
            'Resize','off',...
            'DockControls','off',...
            'IntegerHandle','off',...
            'HandleVisibility','off',...
            'Units','pixels',...
            'Color',get(hParent,'Color'),...
            'Tag','MU_list_chooser');
% Register the window right away, before any event processing can happen
setappdata(hFig,'Popup',hPopup);
setappdata(hPopup,'MU_list_chooser',hFig);
hList=uicontrol(hFig,'Style','listbox',...
                     'String',contents,...
                     'Value',value,...
                     'Units','pixels',...
                     'BackgroundColor','white');

% Size the list to its content: Extent gives the longest entry and the
% height of one text line, rows are drawn somewhat tighter than that
ext=get(hList,'Extent');
rowH=ceil(0.78*ext(4));
listH=nItems*rowH+8;
listW=max(ctrlPos(3),ext(3)+30);

% Open downwards below the control when there is room, otherwise upwards,
% and never taller than the available screen space
margin=4;
roomBelow=ctrlBottom-margin;
roomAbove=scr(4)-ctrlTop-margin;
decoH=30; % window title bar estimate, corrected below
if listH+decoH<=roomBelow || roomBelow>=roomAbove
    room=roomBelow;
    below=true;
else
    room=roomAbove;
    below=false;
end
listH=max(min(listH,room-decoH),3*rowH);
listW=min(listW,scr(3)-ctrlLeft-margin);

set(hList,'Position',[1 1 listW listH]);
set(hFig,'Position',[ctrlLeft ctrlBottom-listH-decoH listW listH],'Visible','on');
drawnow;

% Place the window flush against the control, accounting for the actual
% window decoration height
outer=get(hFig,'OuterPosition');
decoH=max(outer(4)-listH,0);
if below
    bottom=ctrlBottom-listH-decoH;
else
    bottom=ctrlTop;
end
bottom=max(bottom,margin);
set(hFig,'OuterPosition',[ctrlLeft bottom listW listH+decoH]);

% Wire up the callbacks. These are local functions taking explicit
% arguments (not nested functions) so that nothing keeps this function's
% workspace, and with it the busy guard above, alive while the window is open.
setappdata(hFig,'lastInputWasKey',false);
set(hList,'Callback',{@onSelect,hFig,hPopup,selectFcn});
set(hFig,'WindowKeyPressFcn',{@onKey,hList,hPopup,selectFcn},...
         'WindowButtonDownFcn',@(h,~)setappdata(h,'lastInputWasKey',false),...
         'CloseRequestFcn',@(h,~)delete(h));
lh=addlistener(hParent,'ObjectBeingDestroyed',@(~,~)closeChooser(hPopup));
setappdata(hFig,'ParentListener',lh);

end

% A list entry was clicked or reached with the keyboard
function onSelect(hList,~,hFig,hPopup,selectFcn)

applySelection(hPopup,get(hList,'Value'),selectFcn);
% Keyboard navigation keeps the list open, a mouse pick closes it
if ishandle(hFig) && ~getappdata(hFig,'lastInputWasKey')
    delete(hFig);
end

end

function onKey(hFig,evt,hList,hPopup,selectFcn)

setappdata(hFig,'lastInputWasKey',true);
switch evt.Key
    case 'escape'
        delete(hFig);
    case 'return'
        applySelection(hPopup,get(hList,'Value'),selectFcn);
        delete(hFig);
end

end

function applySelection(hPopup,index,selectFcn)

if ~ishandle(hPopup)
    return;
end
current=get(hPopup,'String');
if ischar(current)
    current=cellstr(current);
end
if index>=1 && index<=numel(current)
    set(hPopup,'Value',index);
    selectFcn(index);
end

end

% Close every list window attached to hPopup, return true if one was open
function wasOpen=closeChooser(hPopup)

wasOpen=false;
if ~ishandle(hPopup)
    return;
end
if isappdata(hPopup,'MU_list_chooser')
    rmappdata(hPopup,'MU_list_chooser');
end
% Sweep by tag rather than trusting a single stored handle, so stray
% windows can never accumulate
hFigs=findall(0,'Type','figure','Tag','MU_list_chooser');
for i=1:numel(hFigs)
    if isappdata(hFigs(i),'Popup') && isequal(getappdata(hFigs(i),'Popup'),hPopup)
        wasOpen=true;
        delete(hFigs(i));
    end
end

end

function clearBusy(hPopup)

if ishandle(hPopup) && isappdata(hPopup,'MU_list_chooser_busy')
    rmappdata(hPopup,'MU_list_chooser_busy');
end

end
