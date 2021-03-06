module lib.messages;

import services.kmessage;
import main;
import system.cpu;
import lib.string;

private immutable CONVERSION_TABLE = "0123456789abcdef";
private __gshared size_t    bufferIndex;
private __gshared char[256] buffer;

void log(T...)(T form) {
    format(form);
    sync(KMessagePriority.Log);
}

void warn(T...)(T form) {
    format(form);
    sync(KMessagePriority.Warn);
}

void error(T...)(T form) {
    format(form);
    sync(KMessagePriority.Error);
}

void panic(T...)(T form) {
    addToBuffer("Panic: ");
    format(form);
    addToBuffer("\nThe system will now proceed to die");
    sync(KMessagePriority.Error);

    while (true) {
        asm {
            cli;
            hlt;
        }
    }
}

private void format(T...)(T items) {
    foreach (i; items) {
        addToBuffer(i);
    }
}

private void addToBuffer(ubyte add) {
    addToBuffer(cast(size_t)add);
}

private void addToBuffer(char add) {
    buffer[bufferIndex++] = add;
}

private void addToBuffer(string add) {
    foreach (c; add) {
        addToBuffer(c);
    }
}

private void addToBuffer(void* addr) {
    addToBuffer(cast(size_t)addr);
}

private void addToBuffer(size_t x) {
    int i;
    char[17] buf;

    buf[16] = 0;

    if (!x) {
        addToBuffer("0x0");
        return;
    }

    for (i = 15; x; i--) {
        buf[i] = CONVERSION_TABLE[x % 16];
        x /= 16;
    }

    i++;
    addToBuffer("0x");
    addToBuffer(fromCString(&buf[i]));
}

private void sync(KMessagePriority priority) {
    buffer[bufferIndex] = '\0';
    bufferIndex = 0;

    if (servicesUp) {
        auto msg = KMessage(priority, fromCString(buffer.ptr));
        kmessageQueue.sendMessageSync(msg);
    } else {
        final switch (priority) {
            case KMessagePriority.Log:
                qemuPrint("LOG: ");
                break;
            case KMessagePriority.Warn:
                qemuPrint("WARN: ");
                break;
            case KMessagePriority.Error:
                qemuPrint("ERROR: ");
                break;
        }

        qemuPrint(fromCString(buffer.ptr));
        qemuPrint("\n");
    }
}

private void qemuPrint(string str) {
    foreach (c; str) {
        outb(0xe9, c);
    }
}
