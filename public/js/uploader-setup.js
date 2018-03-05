(function($) {

    $(function() {
        var $fileInput = $('#file-input');
        var $dropBox = $('#drop-box');
        var $uploadForm = $('#upload-form');
        var $uploadRows = $('#upload-rows');
        var $clearBtn = $('#clear-btn');
        var $sendBtn = $('#send-btn');
        var $autostartChecker = $('#autostart-checker');
        var autostartOn = true;
        var $previewsChecker = $('#previews-checker');
        var previewsOn = true;
        var $methodSelect = $('input[name="method"]');

        $fileInput.damnUploader({
            url: '/upload',
            fieldName:  'file',
            dropBox: $dropBox,
            limit: 5,
            dataType: 'json'
        });

        var isTextFile = function(file) {
            return file.type == 'text/plain';
        };

        var isImgFile = function(file) {
            return file.type.match(/image.*/);
        };


        // Creates queue table row with file information and upload status
        function createRowFromUploadItem(ui) {
            var $row = $('<tr/>').prependTo($uploadRows);
            var $progressBar = $('<div/>').addClass('progress-bar').css('width', '0%');
            var $pbWrapper = $('<div/>').addClass('progress').append($progressBar);

            // Defining cancel button & its handler
            var $cancelBtn = $('<a/>').attr('href', 'javascript:').append(
                $('<span/>').addClass('glyphicon glyphicon-remove')
            ).on('click', function() {
                var $statusCell =  $pbWrapper.parent();
                $statusCell.empty().html('<i>'+TextCancel+'</i>');
                ui.cancel();
                $cancelBtn.css('display', 'none');
                log((ui.file.name || "[custom-data]") + " cancelled");
            });

            // Generating preview
            var $preview;
            if (previewsOn) {
                if (isImgFile(ui.file)) {
                    // image preview (note: might work slow with large images)
                    $preview = $('<img/>').attr('width', 120);
                    ui.readAs('DataURL', function(e) {
                        $preview.attr('src', e.target.result);
                    });
                }
                else {$preview = $('<i>no preview</i>');}
            } else {
                $preview = $('<i>no preview</i>');
            }

            // Appending cells to row
            $('<td/>').append($preview).appendTo($row); // Preview
            $('<td/>').text(ui.file.name).appendTo($row); // Filename
            $('<td/>').text(Math.round(ui.file.size / 1024) + ' KB').appendTo($row); // Size in KB
            $('<td/>').append($pbWrapper).appendTo($row); // Status
            $('<td/>').append($cancelBtn).appendTo($row); // Cancel button
            
            var mass = new Array();
            mass[0] = $progressBar;
            mass[1] = $cancelBtn;
            mass[2] = $pbWrapper;
            return mass;
        };

        // File adding handler
        var fileAddHandler = function(e) {
            // e.uploadItem represents uploader task as special object,
            // that allows us to define complete & progress callbacks as well as some another parameters
            // for every single upload
            var ui = e.uploadItem;
            var filename = ui.file.name || ""; // Filename property may be absent when adding custom data

            // We can call preventDefault() method of event to cancel adding
            //if (!isTextFile(ui.file) && !isImgFile(ui.file)) {
            //    log(filename + ": is not image. Only images & plain text files accepted!");
            //    e.preventDefault();
            //    return ;
            //}
            
            if (ui.file.size > 4294967296) {e.preventDefault(); return ;}

            // We can replace original filename if needed
            if (!filename.length) {
                ui.replaceName = "custom-data";
            } else if (filename.length > 14) {
                ui.replaceName = filename.substr(0, 10) + "_" + filename.substr(filename.lastIndexOf('.'));
            }

            // We can add some data to POST in upload request
            ui.addPostData($uploadForm.serializeArray()); // from array
            ui.addPostData('origname', filename); // .. or as field/value pair

            // Show info and response when upload completed
            //var $progressBar = createRowFromUploadItem(ui);
            
            var mass = createRowFromUploadItem(ui);
            var $progressBar = mass[0];
            var $cancelBtn = mass[1];
            var $pbWrapper = mass[2];
            var $statusCell =  $pbWrapper.parent();
            ui.completeCallback = function(success, data, errorCode) {
                log('******');
                log((this.file.name || "[custom-data]") + " completed");
                if (success) {
                    if (!data['error']) { 
                      log('recieved data:', data);
                      $cancelBtn.css('display', 'none');
                      $statusCell.empty().html('<i>'+TextSucess+'</i>');
                    } else {
                      $cancelBtn.css('display', 'none');
                      $statusCell.empty().html('<i>'+TextError+': '+data['error']+'</i>');
                      log('uploading failed: ' + data['error'] + '. Response code is:', errorCode);
                    }
                } else {
                    if (errorCode) {
                      $cancelBtn.css('display', 'none');
                      $statusCell.empty().html('<i>'+TextError+'</i>');
                      log('uploading failed. Response code is:', errorCode);
                    } else {
                      $statusCell.empty().html('<i>'+TextCancel+'</i>');
                    }
                }
                get_user_files();
            };

            // Updating progress bar value in progress callback
            ui.progressCallback = function(percent) {
                var px = 399 - Math.round(percent * $pbWrapper.width() / 100);
                $pbWrapper.css('backgroundPosition', '-' + px + 'px 0px');
                //$progressBar.css('width', Math.round(percent) + '%');
            };

            // To start uploading immediately as soon as added
            autostartOn && ui.upload();
        };


        ///// Setting up events handlers

        // Uploader events
        $fileInput.on({
            'du.add' : fileAddHandler,

            'du.limit' : function() {
                log("File upload limit exceeded!");
            },

            'du.completed' : function() {
                log('******');
                log("All uploads completed!");
            }
        });

        // Clear button
        $clearBtn.on('click', function() {
            $fileInput.duCancelAll();
            $uploadRows.empty();
            log('******');
            log("All uploads canceled :(");
        });

        // Form submit
        $uploadForm.on('submit', function(e) {
            // Sending files by HTML5 File API if available, else - form will be submitted on fallback handler
            if ($.support.fileSending) {
                e.preventDefault();
                $fileInput.duStart();
            }
        });

    });

})(window.jQuery);


// Shorthand log function
window.log = function() {
    window.console && window.console.log && window.console.log.apply(window.console, arguments);
};

(function($) {

    $(function() {
        // Drag & drop events handling
        var $dropBox = $("#drop-box");
        var $uploadForm = $("#upload-form");
        var exitedToForm = false;
        var highlighted = false;
        var highlight = function(mode) {
            mode ? $dropBox.addClass('highlighted') : $dropBox.removeClass('highlighted');
        };
        $dropBox.on({
            dragenter: function() {
                highlight(true);
            },
            dragover: function() {
                highlighted || highlight(true);
                return false; // To prevent default action
            },
            dragleave: function() {
                setTimeout(function() {
                    exitedToForm || highlight(false);
                }, 50);
            },
            drop: function() {
                highlight(false);
            }
        });
        $uploadForm.on({
            dragenter: function() {
                exitedToForm = true;
                highlighted || highlight(true);
            },
            dragleave: function() {
                exitedToForm = false;
            }
        });

    });

})(window.jQuery);

