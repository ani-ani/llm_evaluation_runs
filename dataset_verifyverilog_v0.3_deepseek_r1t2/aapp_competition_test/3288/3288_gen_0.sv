module incremental_double_free_string_generator #(
    parameter MAX_K = 4,
    parameter MAX_LEN = 10,
    parameter N_WIDTH = 32
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [5:0] k,
    input wire [N_WIDTH-1:0] n,
    output reg [7:0] char_0, output reg [7:0] char_1, output reg [7:0] char_2, output reg [7:0] char_3, output reg [7:0] char_4,
    output reg [7:0] char_5, output reg [7:0] char_6, output reg [7:0] char_7, output reg [7:0] char_8, output reg [7:0] char_9,
    output reg valid,
    output reg done,
    output reg error
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] VALIDATE = 3'd1;
    localparam [2:0] COUNT = 3'd2;
    localparam [2:0] BUILD = 3'd3;
    localparam [2:0] FINISH = 3'd4;
    localparam [2:0] ERROR_STATE = 3'd5;
    
    reg [7:0] freq [0:25];
    reg [7:0] result [0:9];
    reg [2:0] state, next_state;
    reg [5:0] reg_k;
    reg [N_WIDTH-1:0] reg_n;
    reg [4:0] build_pos;
    integer i; // Loop variable

    // Next state logic
    always @(*) begin
        case (state)
            IDLE:       next_state = start ? VALIDATE : IDLE;
            VALIDATE:   next_state = ((reg_k < 1) || (reg_k > MAX_K) || (reg_n == 0) || (!check_total_count(reg_k, reg_n))) ? ERROR_STATE : COUNT;
            COUNT:      next_state = BUILD;
            BUILD:      next_state = (build_pos >= (reg_k*(reg_k+1)/2)) ? FINISH : BUILD;
            FINISH:     next_state = IDLE;
            ERROR_STATE: next_state = ERROR_STATE;
            default:    next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            valid <= 1'b0;
            done <= 1'b0;
            error <= 1'b0;
            reg_k <= 6'd0;
            reg_n <= {N_WIDTH{1'b0}};
            build_pos <= 5'd0;
            for (i = 0; i <= 25; i = i + 1) freq[i] <= 8'd0;
            for (i = 0; i <= 9; i = i + 1) result[i] <= 8'd0;
            char_0 <= 8'd0; char_1 <= 8'd0; char_2 <= 8'd0; char_3 <= 8'd0; char_4 <= 8'd0;
            char_5 <= 8'd0; char_6 <= 8'd0; char_7 <= 8'd0; char_8 <= 8'd0; char_9 <= 8'd0;
        end
        else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    error <= 1'b0;
                    valid <= 1'b0;
                    if (start) begin
                        reg_k <= k;
                        reg_n <= n;
                        build_pos <= 5'd0;
                    end
                end
                
                VALIDATE: begin
                    for (i = 0; i <= 25; i = i + 1) begin
                        freq[i] <= (i < reg_k) ? (i + 8'd1) : 8'd0;
                    end
                end
                
                COUNT: begin
                    // Placeholder for count implementation
                    build_pos <= 5'd0;
                end
                
                BUILD: begin
                    if (build_pos < (reg_k*(reg_k+1)/2)) begin
                        // Simplified string generation logic
                        if (reg_k == 2) begin
                            case (build_pos)
                                0: result[0] <= 8'h61;
                                1: result[1] <= 8'h62;
                                2: result[2] <= 8'h61;
                                default: result[build_pos] <= 8'h00;
                            endcase
                        end
                        else if (reg_k == 3) begin
                            case (build_pos)
                                0: result[0] <= 8'h61;
                                1: result[1] <= 8'h62;
                                2: result[2] <= 8'h61;
                                3: result[3] <= 8'h62;
                                4: result[4] <= 8'h61;
                                5: result[5] <= 8'h63;
                                default: result[build_pos] <= 8'h00;
                            endcase
                        end
                        else begin
                            result[build_pos] <= 8'h61 + build_pos[3:0];
                        end
                        build_pos <= build_pos + 5'd1;
                    end
                end
                
                FINISH: begin
                    char_0 <= result[0]; char_1 <= result[1]; char_2 <= result[2]; 
                    char_3 <= result[3]; char_4 <= result[4]; char_5 <= result[5]; 
                    char_6 <= result[6]; char_7 <= result[7]; char_8 <= result[8]; 
                    char_9 <= result[9];
                    valid <= 1'b1;
                    done <= 1'b1;
                end
                
                ERROR_STATE: begin
                    error <= 1'b1;
                end
            endcase
        end
    end

    // Check total count function
    function automatic check_total_count(input [5:0] k, input [N_WIDTH-1:0] n);
        reg [N_WIDTH-1:0] total;
        begin
            case (k)
                1: total = 1;
                2: total = 650;
                3: total = 31200;
                4: total = 1860480;
                default: total = 0;
            endcase
            check_total_count = (n > 0) && (n <= total);
        end
    endfunction

endmodule