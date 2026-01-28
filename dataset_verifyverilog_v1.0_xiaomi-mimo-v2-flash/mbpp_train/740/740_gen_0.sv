module array_to_key_value_pairs (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] data_in [0:7],
    output reg result_valid,
    output reg [7:0] key [0:3],
    output reg [7:0] value [0:3],
    output reg done
);

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] LOAD    = 3'd1;
    localparam [2:0] PROCESS = 3'd2;
    localparam [2:0] DONE    = 3'd3;
    
    reg [2:0] state;
    reg [3:0] index;
    reg [1:0] pair_index;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd16;
    
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_valid <= 1'b0;
            done <= 1'b0;
            index <= 4'd0;
            pair_index <= 2'd0;
            cycle_count <= 8'd0;
            for (i = 0; i < 4; i = i + 1) begin
                key[i] <= 8'd0;
                value[i] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    result_valid <= 1'b0;
                    done <= 1'b0;
                    index <= 4'd0;
                    pair_index <= 2'd0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= LOAD;
                    end
                end
                
                LOAD: begin
                    state <= PROCESS;
                end
                
                PROCESS: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Process current pair
                    if (pair_index < 2'd3) begin
                        key[pair_index]   <= data_in[index];
                        value[pair_index] <= data_in[index + 4'd1];
                        pair_index <= pair_index + 2'd1;
                        index <= index + 4'd2;
                    end else begin
                        // Last pair processed
                        key[3]   <= data_in[6];
                        value[3] <= data_in[7];
                        state <= DONE;
                    end
                end
                
                DONE: begin
                    done <= 1'b1;
                    result_valid <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                    result_valid <= 1'b0;
                end
            endcase
        end
    end

endmodule