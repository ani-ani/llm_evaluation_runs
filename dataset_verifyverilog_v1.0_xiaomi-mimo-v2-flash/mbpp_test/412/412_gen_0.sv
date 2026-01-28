module filter_even_numbers (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr_in [0:7],
    output reg [7:0] arr_out [0:7],
    output reg done,
    output reg [3:0] valid_count
);

    // State machine definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] PROCESS_0 = 3'd1;
    localparam [2:0] PROCESS_1 = 3'd2;
    localparam [2:0] PROCESS_2 = 3'd3;
    localparam [2:0] PROCESS_3 = 3'd4;
    localparam [2:0] PROCESS_4 = 3'd5;
    localparam [2:0] PROCESS_5 = 3'd6;
    localparam [2:0] PROCESS_6 = 3'd7;
    localparam [2:0] PROCESS_7 = 3'd8;
    localparam [2:0] FINISH = 3'd9;

    reg [2:0] state;
    reg [2:0] next_state;
    reg [3:0] count_reg;
    reg [3:0] idx;
    reg [7:0] temp_out [0:7];
    integer i;

    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = PROCESS_0;
                else
                    next_state = IDLE;
            end
            PROCESS_0: next_state = PROCESS_1;
            PROCESS_1: next_state = PROCESS_2;
            PROCESS_2: next_state = PROCESS_3;
            PROCESS_3: next_state = PROCESS_4;
            PROCESS_4: next_state = PROCESS_5;
            PROCESS_5: next_state = PROCESS_6;
            PROCESS_6: next_state = PROCESS_7;
            PROCESS_7: next_state = FINISH;
            FINISH: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            valid_count <= 4'd0;
            idx <= 3'd0;
            count_reg <= 4'd0;
            for (i = 0; i < 8; i = i + 1) begin
                temp_out[i] <= 8'd0;
                arr_out[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
            done <= 1'b0;
            
            case (state)
                IDLE: begin
                    if (start) begin
                        count_reg <= 4'd0;
                        idx <= 3'd0;
                        for (i = 0; i < 8; i = i + 1) begin
                            temp_out[i] <= 8'd0;
                        end
                    end
                end
                
                PROCESS_0: begin
                    if (!arr_in[0][0]) begin
                        temp_out[count_reg] <= arr_in[0];
                        count_reg <= count_reg + 4'd1;
                    end
                    idx <= 3'd1;
                end
                
                PROCESS_1: begin
                    if (!arr_in[1][0]) begin
                        temp_out[count_reg] <= arr_in[1];
                        count_reg <= count_reg + 4'd1;
                    end
                    idx <= 3'd2;
                end
                
                PROCESS_2: begin
                    if (!arr_in[2][0]) begin
                        temp_out[count_reg] <= arr_in[2];
                        count_reg <= count_reg + 4'd1;
                    end
                    idx <= 3'd3;
                end
                
                PROCESS_3: begin
                    if (!arr_in[3][0]) begin
                        temp_out[count_reg] <= arr_in[3];
                        count_reg <= count_reg + 4'd1;
                    end
                    idx <= 3'd4;
                end
                
                PROCESS_4: begin
                    if (!arr_in[4][0]) begin
                        temp_out[count_reg] <= arr_in[4];
                        count_reg <= count_reg + 4'd1;
                    end
                    idx <= 3'd5;
                end
                
                PROCESS_5: begin
                    if (!arr_in[5][0]) begin
                        temp_out[count_reg] <= arr_in[5];
                        count_reg <= count_reg + 4'd1;
                    end
                    idx <= 3'd6;
                end
                
                PROCESS_6: begin
                    if (!arr_in[6][0]) begin
                        temp_out[count_reg] <= arr_in[6];
                        count_reg <= count_reg + 4'd1;
                    end
                    idx <= 3'd7;
                end
                
                PROCESS_7: begin
                    if (!arr_in[7][0]) begin
                        temp_out[count_reg] <= arr_in[7];
                        count_reg <= count_reg + 4'd1;
                    end
                end
                
                FINISH: begin
                    // Copy temp_out to arr_out with zeros for unused positions
                    for (i = 0; i < 8; i = i + 1) begin
                        if (i < count_reg)
                            arr_out[i] <= temp_out[i];
                        else
                            arr_out[i] <= 8'd0;
                    end
                    valid_count <= count_reg;
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule