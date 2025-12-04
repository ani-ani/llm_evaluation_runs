module list_splitter (
    input reg [7:0] data [0:7],
    input reg [2:0] step,
    output reg [63:0] sublists
);
    // Internal logic
    logic [2:0] step_clamped;
    assign step_clamped = (step > 3'd4) ? 3'd4 : step;
    always_comb begin
        sublists = 64'b0;
        for (int i = 0; i < 4; i++) begin
            if (i < step_clamped) begin
                // First element of sublist i
                if (i < 8) begin
                    sublists[i*16 +: 8] = data[i];
                end
                // Second element of sublist i
                if ((i + step_clamped) < 8) begin
                    sublists[i*16 + 8 +: 8] = data[i + step_clamped];
                end
            end
        end
    end
endmodule