import * as toolcraft from 'toolcraft';

declare const garminPilotCommands: toolcraft.Group<{
    [x: string]: never;
}> & {
    readonly __agentKitGroupTypeInfo: toolcraft.GroupTypeInfo<{
        [x: string]: never;
    }, "garmin", ((toolcraft.Command<{
        [x: string]: never;
    }, toolcraft.ObjectSchema<{
        readonly device: toolcraft.StringSchema;
        readonly prg: toolcraft.StringSchema;
        readonly path: toolcraft.StringSchema;
        readonly region: toolcraft.OptionalSchema<toolcraft.EnumSchema<readonly ["window", "device", "framebuffer"]>>;
    }>, undefined, {
        path: string;
        window: {
            id: number;
            pid: number;
            title: string;
            x: number;
            y: number;
            width: number;
            height: number;
        };
    }> & {
        readonly __agentKitCommandTypeInfo: toolcraft.CommandTypeInfo<"screenshot", toolcraft.ObjectSchema<{
            readonly device: toolcraft.StringSchema;
            readonly prg: toolcraft.StringSchema;
            readonly path: toolcraft.StringSchema;
            readonly region: toolcraft.OptionalSchema<toolcraft.EnumSchema<readonly ["window", "device", "framebuffer"]>>;
        }>, {
            path: string;
            window: {
                id: number;
                pid: number;
                title: string;
                x: number;
                y: number;
                width: number;
                height: number;
            };
        }, undefined, undefined>;
    }) | (toolcraft.Command<{
        [x: string]: never;
    }, toolcraft.ObjectSchema<{
        readonly device: toolcraft.StringSchema;
        readonly prg: toolcraft.StringSchema;
        readonly button: toolcraft.EnumSchema<readonly ["Light", "Up", "Down", "Start", "Back", "Menu"]>;
        readonly screenshot: toolcraft.OptionalSchema<toolcraft.StringSchema>;
    }>, undefined, {
        ok: boolean;
        screenshot: string | undefined;
    }> & {
        readonly __agentKitCommandTypeInfo: toolcraft.CommandTypeInfo<"press", toolcraft.ObjectSchema<{
            readonly device: toolcraft.StringSchema;
            readonly prg: toolcraft.StringSchema;
            readonly button: toolcraft.EnumSchema<readonly ["Light", "Up", "Down", "Start", "Back", "Menu"]>;
            readonly screenshot: toolcraft.OptionalSchema<toolcraft.StringSchema>;
        }>, {
            ok: boolean;
            screenshot: string | undefined;
        }, undefined, undefined>;
    }) | (toolcraft.Command<{
        [x: string]: never;
    }, toolcraft.ObjectSchema<{
        readonly device: toolcraft.StringSchema;
        readonly prg: toolcraft.StringSchema;
        readonly x: toolcraft.NumberSchema;
        readonly y: toolcraft.NumberSchema;
        readonly screenshot: toolcraft.OptionalSchema<toolcraft.StringSchema>;
    }>, undefined, {
        ok: boolean;
        screenshot: string | undefined;
    }> & {
        readonly __agentKitCommandTypeInfo: toolcraft.CommandTypeInfo<"tap", toolcraft.ObjectSchema<{
            readonly device: toolcraft.StringSchema;
            readonly prg: toolcraft.StringSchema;
            readonly x: toolcraft.NumberSchema;
            readonly y: toolcraft.NumberSchema;
            readonly screenshot: toolcraft.OptionalSchema<toolcraft.StringSchema>;
        }>, {
            ok: boolean;
            screenshot: string | undefined;
        }, undefined, undefined>;
    }) | (toolcraft.Command<{
        [x: string]: never;
    }, toolcraft.ObjectSchema<{
        readonly device: toolcraft.StringSchema;
        readonly prg: toolcraft.StringSchema;
        readonly fromX: toolcraft.NumberSchema;
        readonly fromY: toolcraft.NumberSchema;
        readonly toX: toolcraft.NumberSchema;
        readonly toY: toolcraft.NumberSchema;
        readonly durationMs: toolcraft.OptionalSchema<toolcraft.NumberSchema>;
        readonly screenshot: toolcraft.OptionalSchema<toolcraft.StringSchema>;
    }>, undefined, {
        ok: boolean;
        screenshot: string | undefined;
    }> & {
        readonly __agentKitCommandTypeInfo: toolcraft.CommandTypeInfo<"swipe", toolcraft.ObjectSchema<{
            readonly device: toolcraft.StringSchema;
            readonly prg: toolcraft.StringSchema;
            readonly fromX: toolcraft.NumberSchema;
            readonly fromY: toolcraft.NumberSchema;
            readonly toX: toolcraft.NumberSchema;
            readonly toY: toolcraft.NumberSchema;
            readonly durationMs: toolcraft.OptionalSchema<toolcraft.NumberSchema>;
            readonly screenshot: toolcraft.OptionalSchema<toolcraft.StringSchema>;
        }>, {
            ok: boolean;
            screenshot: string | undefined;
        }, undefined, undefined>;
    }))[], undefined, undefined>;
};
declare function createGarminPilotToolcraftSDK(): {
    screenshot: (params: {
        device: string;
        prg: string;
        path: string;
        region?: "window" | "device" | "framebuffer" | undefined;
    }) => Promise<{
        path: string;
        window: {
            id: number;
            pid: number;
            title: string;
            x: number;
            y: number;
            width: number;
            height: number;
        };
    }>;
    press: (params: {
        device: string;
        prg: string;
        button: "Light" | "Up" | "Down" | "Start" | "Back" | "Menu";
        screenshot?: string | undefined;
    }) => Promise<{
        ok: boolean;
        screenshot: string | undefined;
    }>;
    tap: (params: {
        device: string;
        prg: string;
        x: number;
        y: number;
        screenshot?: string | undefined;
    }) => Promise<{
        ok: boolean;
        screenshot: string | undefined;
    }>;
    swipe: (params: {
        device: string;
        prg: string;
        fromx: number;
        fromy: number;
        tox: number;
        toy: number;
        screenshot?: string | undefined;
        durationMs?: number | undefined;
    }) => Promise<{
        ok: boolean;
        screenshot: string | undefined;
    }>;
};

export { createGarminPilotToolcraftSDK, garminPilotCommands };
