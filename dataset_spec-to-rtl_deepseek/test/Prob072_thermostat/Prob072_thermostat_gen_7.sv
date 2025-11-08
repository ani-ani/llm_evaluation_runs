module TopModule(
    input reg mode,
    input reg too_cold,
    input reg too_hot,
    input reg fan_on,
    output heater,
    output aircon,
    output fan
);
    assign heater = mode && too_cold;
    assign aircon = !mode && too_hot;
    assign fan = (heater || aircon) || fan_on;
endmodule