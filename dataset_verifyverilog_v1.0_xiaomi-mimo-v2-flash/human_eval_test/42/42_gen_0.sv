module array_increment (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr_in [0:7],
    input wire [3:0] len,
    output reg [7:0] arr_out [0:7],
    output reg done
);

    // State definitions
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] PROCESS = 2'd1;
    localparam [1:0] FINISH  = 2'd2;

    reg [1:0] state;
    reg [7:0] latched_arr [0:7];
    reg [3:0] latched_len;
    reg [3:0] counter;
    
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            counter <= 4'd0;
            latched_len <= 4'd0;
            for (i = 0; i < 8; i = i + 1) begin
                latched_arr[i] <= 8'd0;
                arr_out[i] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    counter <= 4'd0;
                    if (start) begin
                        // Latch inputs
                        for (i = 0; i < 8; i = i + 1) begin
                            latched_arr[i] <= arr_in[i];
                        end
                        latched_len <= len;
                        state <= PROCESS;
                    end
                end
                
                PROCESS: begin
                    // Process elements sequentially
                    if (counter < latched_len && counter < 8'd8) begin
                        // Increment with overflow wrap
                        if (latched_arr[counter] == 8'd255) begin
                            arr_out[counter] <= 8'd0;
                        end else begin
                            arr_out[counter] <= latched_arr[counter] + 8'd1;
                        end
                        counter <= counter + 4'd1;
                    end else begin
                        // Set remaining elements to 0
                        if (counter < 8'd8) begin
                            arr_out[counter] <= 8'd0;
                            counter <= counter + 4'd1;
                        end else begin
                            state <= FINISH;
                        end
                    end
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