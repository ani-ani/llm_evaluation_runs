module arrow_reconstruction(
    input clk,               
    input rst_n,             
    input start,             
    input [15:0] K,          
    input [3:0] a[15:0],     
    output reg [3:0] arrows[15:0], 
    output reg done          
);

typedef enum logic [1:0] {
    IDLE, 
    FIND_CYCLES, 
    COMPUTE_BACK_STEPS, 
    DONE
} state_t;

state_t state, next_state;
reg [15:0] visited;
reg [3:0] current_idx;
reg [3:0] cycle_data[0:15];
reg [4:0] cycle_length;
reg [3:0] temp_element;
reg [3:0] compute_idx;
reg [15:0] mod_result;
reg [15:0] back_steps;
reg error_flag;
reg [15:0] temp_arrows[0:15];

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 1'b0;
        visited <= 16'b0;
        current_idx <= 4'b0;
        error_flag <= 1'b0;
        for (int i=0; i<16; i++) begin
            arrows[i] <= 4'b0;
            temp_arrows[i] <= 4'b0;
        end
    end else begin
        case(state)
            IDLE: begin
                done <= 1'b0;
                error_flag <= 1'b0;
                if (start) begin
                    state <= FIND_CYCLES;
                    visited <= 16'b0;
                    current_idx <= 4'b0;
                end
            end

            FIND_CYCLES: begin
                if (visited[current_idx]) begin
                    current_idx <= current_idx + 1;
                    if (current_idx == 4'd15) state <= DONE;
                end else begin
                    visited[current_idx] <= 1'b1;
                    cycle_data[0] <= current_idx;
                    cycle_length <= 5'd1;
                    temp_element <= a[current_idx];
                    state <= FIND_CYCLES;
                    if (current_idx == a[current_idx]) begin
                        back_steps <= (5'd1 - (K % 16'd1)) % 16'd1;
                        state <= COMPUTE_BACK_STEPS;
                        compute_idx <= 4'b0;
                    end
                end
                
                if (!visited[current_idx] && current_idx != a[current_idx]) begin
                    state <= FIND_CYCLES;
                    temp_element <= a[current_idx];
                    cycle_length <= 5'd0;
                    compute_idx <= 4'b0;
                end
            end

            COMPUTE_BACK_STEPS: begin
                if (cycle_length == 0) begin
                    state <= FIND_CYCLES;
                    current_idx <= current_idx + 1;
                end else begin
                    mod_result <= K % cycle_length;
                    back_steps <= (cycle_length - mod_result[3:0]) % cycle_length;
                    
                    for (int i=0; i<cycle_length; i++) begin
                        automatic int pos = (i + back_steps[3:0]) % cycle_length;
                        temp_arrows[cycle_data[pos]] <= a[cycle_data[i]];
                    end
                    
                    compute_idx <= compute_idx + 1;
                    if (compute_idx == 4'd15) begin
                        for (int i=0; i<16; i++) begin
                            arrows[i] <= temp_arrows[i];
                        end
                        state <= DONE;
                    end else if (current_idx == 4'd15) begin
                        state <= DONE;
                    end else begin
                        current_idx <= current_idx + 1;
                        state <= FIND_CYCLES;
                    end
                end
            end

            DONE: begin
                done <= 1'b1;
                if (!start) state <= IDLE;
            end
        endcase
        
        if (error_flag) begin
            for (int i=0; i<16; i++) arrows[i] <= 4'b0;
            done <= 1'b1;
        end
    end
end

endmodule