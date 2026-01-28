module xor_even_pairs(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr [0:15],
    input wire [3:0] len,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COUNT   = 2'd1;
    localparam [1:0] COMPUTE = 2'd2;
    localparam [1:0] FINISH  = 2'd3;
    
    // Internal registers
    reg [1:0] state;
    reg [3:0] even_count;
    reg [3:0] odd_count;
    reg [15:0] even_pairs;
    reg [15:0] odd_pairs;
    reg [3:0] captured_len;
    reg [7:0] captured_arr [0:15];
    reg [3:0] i;

    // Capture array and length on start
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            even_count <= 4'd0;
            odd_count <= 4'd0;
            even_pairs <= 16'd0;
            odd_pairs <= 16'd0;
            captured_len <= 4'd0;
            for (i = 0; i < 16; i = i + 1) begin
                captured_arr[i] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= COUNT;
                        captured_len <= len;
                        for (i = 0; i < 16; i = i + 1) begin
                            captured_arr[i] <= arr[i];
                        end
                    end
                end
                
                COUNT: begin
                    even_count <= 4'd0;
                    odd_count <= 4'd0;
                    for (i = 0; i < captured_len; i = i + 1) begin
                        if (captured_arr[i][0] == 1'b0) begin
                            even_count <= even_count + 4'd1;
                        end else begin
                            odd_count <= odd_count + 4'd1;
                        end
                    end
                    state <= COMPUTE;
                end
                
                COMPUTE: begin
                    // Compute even_pairs = E*(E-1)/2
                    even_pairs <= (even_count * (even_count - 4'd1)) >> 1;
                    // Compute odd_pairs = O*(O-1)/2
                    odd_pairs <= (odd_count * (odd_count - 4'd1)) >> 1;
                    // Sum results
                    result <= even_pairs + odd_pairs;
                    state <= FINISH;
                end
                
                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule