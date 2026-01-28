module swap_first_last (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr [0:15],
    input wire [3:0] len,
    output reg [7:0] result [0:15],
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] CAPTURE = 2'd1;
    localparam [1:0] FINISH = 2'd2;

    reg [1:0] state;
    reg [7:0] stored_arr [0:15];
    reg [3:0] stored_len;
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            stored_len <= 4'd0;
            for (i = 0; i < 16; i = i + 1) begin
                stored_arr[i] <= 8'd0;
                result[i] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= CAPTURE;
                        // Capture input array and len
                        stored_len <= len;
                        for (i = 0; i < 16; i = i + 1) begin
                            stored_arr[i] <= arr[i];
                        end
                    end
                end

                CAPTURE: begin
                    // Perform swap in this cycle
                    // First, copy all elements unchanged
                    for (i = 0; i < 16; i = i + 1) begin
                        result[i] <= stored_arr[i];
                    end
                    // Then apply swap if len >= 2
                    if (stored_len >= 4'd2) begin
                        result[0] <= stored_arr[stored_len - 4'd1];
                        result[stored_len - 4'd1] <= stored_arr[0];
                    end
                    // Set done and move to FINISH
                    done <= 1'b1;
                    state <= FINISH;
                end

                FINISH: begin
                    done <= 1'b0;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule