@echo off
if [%1]==[fix] (
    npx @iobroker/fix
) else (
    if exist serviceIoBroker.bat (
        if [%1]==[start] (
            if [%2]==[] (
                call serviceIoBroker.bat start
            ) else (
                node node_modules/iobroker.js-controller/iobroker.js %1 %2 %3 %4 %5 %6 %7 %8
            )
        ) else (
            if [%1]==[stop] (
                if [%2]==[] (
                    call serviceIoBroker.bat stop
                ) else (
                    node node_modules/iobroker.js-controller/iobroker.js %1 %2 %3 %4 %5 %6 %7 %8
                )
            ) else (
				if [%1]==[restart] (
					if [%2]==[] (
						call serviceIoBroker.bat restart
					) else (
						node node_modules/iobroker.js-controller/iobroker.js %*
					)
				) else (
					node node_modules/iobroker.js-controller/iobroker.js %1 %2 %3 %4 %5 %6 %7 %8
				)
            )
        )
    ) else (
        node node_modules/iobroker.js-controller/iobroker.js %1 %2 %3 %4 %5 %6 %7 %8
    )
)