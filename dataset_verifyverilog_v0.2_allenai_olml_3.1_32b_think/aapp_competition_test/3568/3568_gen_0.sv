module floppy_organ_checker (
    input wire [3:0] f,
    input wire [19:0] t_i,
    input wire [6:0] n_i,
    input wire [19:0] interval_start [0:9],
    input wire [19:0] interval_end [0:9],
    output wire possible
);

localparam MAX_INTERVALS = 10;

always @(*) begin
    possible = 1'b1;

    if (n_i > 0) begin
        if (interval_start[0] >= interval_end[0]) possible = 1'b0;
        for (int i=1; i < MAX_INTERVALS; i=i+1) begin
            if (i < n_i) begin
                if (interval_start[i] >= interval_end[i]) possible = 1'b0;
            end
        end
    end

    if (n_i > 1) begin
        for (int i=1; i < MAX_INTERVALS; i=i+1) begin
            if (i < n_i) begin
                if (interval_end[i-1] + 1 > interval_start[i]) possible = 1'b0;
            end
        end
    end
end

endmodule