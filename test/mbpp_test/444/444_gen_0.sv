module trim_tuples(
    input  logic        clk,
    input  logic        rst_n,
    input  logic        start,
    input  logic [1:0]  K,
    input  logic [19:0] tuple_in,
    output logic [11:0] tuple_out,
    output logic        done
);

    logic [11:0] next_tuple_out;
    logic        next_done;

    // Combinational logic to determine next outputs
    always_comb begin
        next_tuple_out = 12'b0;
        next_done      = 1'b0;

        if (start) begin
            next_done = 1'b1;
            unique case (K)
                2'd0: begin
                    // Keep all 5 elements; only lowest 3 fit in 12 bits
                    next_tuple_out = { tuple_in[7:4], tuple_in[11:8], tuple_in[15:12] };
                end
                2'd1: begin
                    // Keep elements [1], [2], [3]
                    next_tuple_out = { tuple_in[7:4], tuple_in[11:8], tuple_in[15:12] };
                end
                2'd2: begin
                    // Keep element [2]; pad upper bits with 0
                    next_tuple_out = { 8'b0, tuple_in[11:8] };
                end
                default: begin
                    next_tuple_out = 12'b0;
                    next_done      = 1'b1;
                end
            endcase
        end
    end

    // Sequential logic: 1-cycle latency and reset behavior
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tuple_out <= 12'b0;
            done      <= 1'b0;
        end else begin
            tuple_out <= next_tuple_out;
            done      <= next_done;
        end
    end

endmodule