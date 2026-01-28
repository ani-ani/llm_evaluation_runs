module MinMexOptimizer (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [3:0] m,
    input wire valid_in,
    input wire [3:0] l_in,
    input wire [3:0] r_in,
    output reg [4:0] min_length,
    output reg [63:0] result_array,
    output reg done
);
    localparam [1:0] IDLE = 2'b00;
    localparam [1:0] PROCESS = 2'b01;
    localparam [1:0] GENERATE = 2'b10;
    localparam [1:0] FINISH = 2'b11;
    
    reg [1:0] state;
    reg [3:0] query_count;
    reg [4:0] current_min;
    reg [4:0] length;
    reg [3:0] i_reg;
    reg [3:0] temp_mod;
    reg [3:0] temp_i;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            min_length <= 5'b0;
            result_array <= 64'b0;
            query_count <= 4'b0;
            current_min <= 5'b11111;
            length <= 5'b0;
            i_reg <= 4'b0;
            temp_mod <= 4'b0;
            temp_i <= 4'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        query_count <= 4'b0;
                        current_min <= 5'b11111;
                        state <= PROCESS;
                    end
                end
                
                PROCESS: begin
                    if (valid_in && (query_count < m)) begin
                        length <= r_in - l_in + 1'b1;
                        if ((r_in - l_in + 1'b1) < current_min) begin
                            current_min <= r_in - l_in + 1'b1;
                        end
                        query_count <= query_count + 1'b1;
                    end else if (query_count == m) begin
                        state <= GENERATE;
                        i_reg <= 4'b0;
                    end
                end
                
                GENERATE: begin
                    if (i_reg < n) begin
                        if (current_min != 5'b0) begin
                            temp_i <= i_reg;
                            temp_mod <= i_reg % current_min[3:0];
                        end else begin
                            temp_mod <= 4'b0;
                        end
                        i_reg <= i_reg + 1'b1;
                    end else begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    min_length <= current_min;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
            
            if (state == GENERATE && i_reg < n) begin
                case (i_reg)
                    4'd0:  result_array[3:0]   <= (current_min != 5'b0) ? (0 % current_min[3:0]) : 4'b0;
                    4'd1:  result_array[7:4]   <= (current_min != 5'b0) ? (1 % current_min[3:0]) : 4'b0;
                    4'd2:  result_array[11:8]  <= (current_min != 5'b0) ? (2 % current_min[3:0]) : 4'b0;
                    4'd3:  result_array[15:12] <= (current_min != 5'b0) ? (3 % current_min[3:0]) : 4'b0;
                    4'd4:  result_array[19:16] <= (current_min != 5'b0) ? (4 % current_min[3:0]) : 4'b0;
                    4'd5:  result_array[23:20] <= (current_min != 5'b0) ? (5 % current_min[3:0]) : 4'b0;
                    4'd6:  result_array[27:24] <= (current_min != 5'b0) ? (6 % current_min[3:0]) : 4'b0;
                    4'd7:  result_array[31:28] <= (current_min != 5'b0) ? (7 % current_min[3:0]) : 4'b0;
                    4'd8:  result_array[35:32] <= (current_min != 5'b0) ? (8 % current_min[3:0]) : 4'b0;
                    4'd9:  result_array[39:36] <= (current_min != 5'b0) ? (9 % current_min[3:0]) : 4'b0;
                    4'd10: result_array[43:40] <= (current_min != 5'b0) ? (10 % current_min[3:0]) : 4'b0;
                    4'd11: result_array[47:44] <= (current_min != 5'b0) ? (11 % current_min[3:0]) : 4'b0;
                    4'd12: result_array[51:48] <= (current_min != 5'b0) ? (12 % current_min[3:0]) : 4'b0;
                    4'd13: result_array[55:52] <= (current_min != 5'b0) ? (13 % current_min[3:0]) : 4'b0;
                    4'd14: result_array[59:56] <= (current_min != 5'b0) ? (14 % current_min[3:0]) : 4'b0;
                    4'd15: result_array[63:60] <= (current_min != 5'b0) ? (15 % current_min[3:0]) : 4'b0;
                    default: result_array[3:0] <= 4'b0;
                endcase
            end
        end
    end
endmodule