module tuple_dict_appender (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [31:0] tuple_data_0,
    input wire [31:0] tuple_data_1,
    input wire [31:0] tuple_data_2,
    input wire [31:0] tuple_data_3,
    input wire [31:0] dict_data,
    output reg [31:0] result_0,
    output reg [31:0] result_1,
    output reg [31:0] result_2,
    output reg [31:0] result_3,
    output reg [31:0] result_4,
    output reg done
);

// State machine definitions
localparam [1:0] IDLE  = 2'd0;
localparam [1:0] COPY  = 2'd1;
localparam [1:0] APPEND = 2'd2;
localparam [1:0] FINISH = 2'd3;

reg [1:0] state, next_state;
reg [2:0] copy_index;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        result_0 <= 32'd0;
        result_1 <= 32'd0;
        result_2 <= 32'd0;
        result_3 <= 32'd0;
        result_4 <= 32'd0;
        done <= 1'b0;
        copy_index <= 3'd0;
    end else begin
        state <= next_state;
        
        case (state)
            IDLE: begin
                done <= 1'b0;
                copy_index <= 3'd0;
                if (start) begin
                    next_state <= COPY;
                end else begin
                    next_state <= IDLE;
                end
            end
            
            COPY: begin
                case (copy_index)
                    3'd0: result_0 <= tuple_data_0;
                    3'd1: result_1 <= tuple_data_1;
                    3'd2: result_2 <= tuple_data_2;
                    3'd3: result_3 <= tuple_data_3;
                    default: begin
                        result_0 <= result_0;
                        result_1 <= result_1;
                        result_2 <= result_2;
                        result_3 <= result_3;
                    end
                endcase
                
                if (copy_index < 3'd3) begin
                    copy_index <= copy_index + 3'd1;
                    next_state <= COPY;
                end else begin
                    next_state <= APPEND;
                end
            end
            
            APPEND: begin
                result_4 <= dict_data;
                done <= 1'b1;
                next_state <= FINISH;
            end
            
            FINISH: begin
                done <= 1'b0;
                if (!start) begin
                    next_state <= IDLE;
                end else begin
                    next_state <= FINISH;
                end
            end
            
            default: begin
                next_state <= IDLE;
                result_0 <= 32'd0;
                result_1 <= 32'd0;
                result_2 <= 32'd0;
                result_3 <= 32'd0;
                result_4 <= 32'd0;
                done <= 1'b0;
                copy_index <= 3'd0;
            end
        endcase
    end
end

endmodule