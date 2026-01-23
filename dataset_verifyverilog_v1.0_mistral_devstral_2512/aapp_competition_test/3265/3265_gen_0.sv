module vacation_planner(
    input clk,
    input rst_n,
    input start,
    input [4:0] L,
    input [63:0] trans_matrix [15:0],
    output reg [5:0] T,
    output reg done
);

    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT = 3'd1;
    localparam [2:0] UPDATE = 3'd2;
    localparam [2:0] DONE_STATE = 3'd3;
    
    localparam MAX_N = 8;
    localparam MAX_DAYS = 16 + 9;
    
    reg [2:0] state;
    reg [7:0] day_counter;
    reg [5:0] min_T;
    reg found_valid_T;
    
    reg signed [31:0] state_vector [0:7];
    reg signed [31:0] new_state_vector [0:7];
    
    integer i, j;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            day_counter <= 8'd0;
            min_T <= 6'd0;
            found_valid_T <= 1'b0;
            T <= 6'd0;
            done <= 1'b0;
            
            for (i = 0; i < MAX_N; i = i + 1) begin
                state_vector[i] <= 32'd0;
                new_state_vector[i] <= 32'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= INIT;
                    end
                end
                
                INIT: begin
                    state_vector[0] <= 32'd256;
                    for (i = 1; i < MAX_N; i = i + 1) begin
                        state_vector[i] <= 32'd0;
                    end
                    day_counter <= 8'd0;
                    min_T <= 6'd63;
                    found_valid_T <= 1'b0;
                    state <= UPDATE;
                end
                
                UPDATE: begin
                    day_counter <= day_counter + 8'd1;
                    
                    for (j = 0; j < MAX_N; j = j + 1) begin
                        new_state_vector[j] <= 32'd0;
                        for (i = 0; i < MAX_N; i = i + 1) begin
                            new_state_vector[j] <= new_state_vector[j] + 
                                (state_vector[i] * trans_matrix[i*MAX_N + j][7:0]);
                        end
                        new_state_vector[j] <= new_state_vector[j] >> 8;
                    end
                    
                    for (i = 0; i < MAX_N; i = i + 1) begin
                        state_vector[i] <= new_state_vector[i];
                    end
                    
                    if (day_counter >= L && day_counter <= L + 9'd9) begin
                        if (state_vector[MAX_N-1] >= 32'd242 && 
                            state_vector[MAX_N-1] <= 32'd244) begin
                            if (!found_valid_T || day_counter < min_T) begin
                                min_T <= day_counter;
                                found_valid_T <= 1'b1;
                            end
                        end
                    end
                    
                    if (day_counter >= MAX_DAYS) begin
                        if (found_valid_T) begin
                            T <= min_T;
                        end else begin
                            T <= 6'd63;
                        end
                        state <= DONE_STATE;
                    end
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule