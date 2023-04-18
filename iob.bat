@echo off
if [%1]==[fix] (
    npx @iobroker/fix
) else (
    if exist serviceIoBroker.bat (
        if [%1]==[start] (
            if [%2]==[] (
                call serviceIoBroker.bat start
            ) else (
                node node_modules/iobroker.js-controller/iobroker.js %*
            )
        ) else (
            if [%1]==[stop] (
                if [%2]==[] (
                    call serviceIoBroker.bat stop
                ) else (
                    node node_modules/iobroker.js-controller/iobroker.js %*
                )
            ) else (
				if [%1]==[restart] (
					if [%2]==[] (
						call serviceIoBroker.bat restart
					) else (
						node node_modules/iobroker.js-controller/iobroker.js %*
					)
				) else (
					node node_modules/iobroker.js-controller/iobroker.js %*
				)
            )
        )
    ) else (
        node node_modules/iobroker.js-controller/iobroker.js %*
    )
)
