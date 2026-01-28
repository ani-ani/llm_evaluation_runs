module odd_filter (
    input clk,
    input rst_n,
    input start,
    input in_valid,
    input wire [7:0] in_arr [15:0],
    input [3:0] in_len,
    output reg out_valid,
    output reg [3:0] out_count,
    output reg [7:0] out_arr [15:0]
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESS = 2'd1;
    localparam [1:0] DONE = 2'd2;

    // Internal registers
    reg [1:0] state;
    reg [3:0] input_idx;
    reg [3:0] output_idx;
    reg [3:0] current_len;
    reg processing;

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            out_valid <= 1'b0;
            out_count <= 4'd0;
            input_idx <= 4'd0;
            output_idx <= 4'd0;
            current_len <= 4'd0;
            processing <= 1'b0;
            // Initialize output array
            for (i = 0; i < 16; i = i + 1) begin
                out_arr[i] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    out_valid <= 1'b0;
                    input_idx <= 4'd0;
                    output_idx <= 4'd0;
                    if (start && in_valid) begin
                        current_len <= in_len;
                        state <= PROCESS;
                        processing <= 1'b1;
                    end
                end

                PROCESS: begin
                    if (processing && input_idx < current_len) begin
                        // Check if current element is odd (LSB = 1)
                        if (in_arr[input_idx][0]) begin
                            if (output_idx < 4'd16) begin
                                out_arr[output_idx] <= in_arr[input_idx];
                                output_idx <= output_idx + 4'd1;
                            end
                        end
                        input_idx <= input_idx + 4'd1;
                    end else if (input_idx >= current_len) begin
                        // Processing complete
                        processing <= 1'b0;
                        out_count <= output_idx;
                        state <= DONE;
                    end
                end

                DONE: begin
                    out_valid <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule