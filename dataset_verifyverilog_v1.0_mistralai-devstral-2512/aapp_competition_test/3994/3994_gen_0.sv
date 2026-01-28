module lights_sim(
    input clk,
    input rst_n,
    input start,
    input [99:0] init_state,
    input [99:0][2:0] a,
    input [99:0][2:0] b,
    output reg [7:0] max_on,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] SIMULATE = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    reg [1:0] state;
    reg [7:0] time_counter;
    reg [7:0] current_on_count;
    reg [7:0] max_on_reg;
    reg [99:0] latched_init_state;
    reg [99:0][2:0] latched_a;
    reg [99:0][2:0] latched_b;
    
    // Combinational logic for light states
    wire [99:0] light_states;
    genvar i;
    generate
        for (i = 0; i < 100; i = i + 1) begin : light_gen
            wire toggle_count_even;
            wire [7:0] time_diff;
            wire [7:0] toggle_count;
            
            assign time_diff = (time_counter >= latched_b[i]) ? (time_counter - latched_b[i]) : 8'd0;
            assign toggle_count = (time_diff / latched_a[i]) + 1;
            assign toggle_count_even = (toggle_count[0] == 1'b0);
            
            assign light_states[i] = (time_counter < latched_b[i]) ? latched_init_state[i] : 
                                   (toggle_count_even ? latched_init_state[i] : ~latched_init_state[i]);
        end
    endgenerate
    
    // Combinational logic to count ON lights
    wire [7:0] on_count;
    assign on_count = light_states[0] + light_states[1] + light_states[2] + light_states[3] + 
                     light_states[4] + light_states[5] + light_states[6] + light_states[7] + 
                     light_states[8] + light_states[9] + light_states[10] + light_states[11] + 
                     light_states[12] + light_states[13] + light_states[14] + light_states[15] + 
                     light_states[16] + light_states[17] + light_states[18] + light_states[19] + 
                     light_states[20] + light_states[21] + light_states[22] + light_states[23] + 
                     light_states[24] + light_states[25] + light_states[26] + light_states[27] + 
                     light_states[28] + light_states[29] + light_states[30] + light_states[31] + 
                     light_states[32] + light_states[33] + light_states[34] + light_states[35] + 
                     light_states[36] + light_states[37] + light_states[38] + light_states[39] + 
                     light_states[40] + light_states[41] + light_states[42] + light_states[43] + 
                     light_states[44] + light_states[45] + light_states[46] + light_states[47] + 
                     light_states[48] + light_states[49] + light_states[50] + light_states[51] + 
                     light_states[52] + light_states[53] + light_states[54] + light_states[55] + 
                     light_states[56] + light_states[57] + light_states[58] + light_states[59] + 
                     light_states[60] + light_states[61] + light_states[62] + light_states[63] + 
                     light_states[64] + light_states[65] + light_states[66] + light_states[67] + 
                     light_states[68] + light_states[69] + light_states[70] + light_states[71] + 
                     light_states[72] + light_states[73] + light_states[74] + light_states[75] + 
                     light_states[76] + light_states[77] + light_states[78] + light_states[79] + 
                     light_states[80] + light_states[81] + light_states[82] + light_states[83] + 
                     light_states[84] + light_states[85] + light_states[86] + light_states[87] + 
                     light_states[88] + light_states[89] + light_states[90] + light_states[91] + 
                     light_states[92] + light_states[93] + light_states[94] + light_states[95] + 
                     light_states[96] + light_states[97] + light_states[98] + light_states[99];

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            time_counter <= 8'd0;
            current_on_count <= 8'd0;
            max_on_reg <= 8'd0;
            max_on <= 8'd0;
            done <= 1'b0;
            
            // Initialize latched arrays
            integer j;
            for (j = 0; j < 100; j = j + 1) begin
                latched_init_state[j] <= 1'b0;
                latched_a[j] <= 3'd0;
                latched_b[j] <= 3'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Latch inputs
                        integer k;
                        for (k = 0; k < 100; k = k + 1) begin
                            latched_init_state[k] <= init_state[k];
                            latched_a[k] <= a[k];
                            latched_b[k] <= b[k];
                        end
                        
                        state <= SIMULATE;
                        time_counter <= 8'd0;
                        current_on_count <= 8'd0;
                        max_on_reg <= 8'd0;
                    end
                end
                
                SIMULATE: begin
                    // Update current ON count
                    current_on_count <= on_count;
                    
                    // Update max_on if current count is greater
                    if (current_on_count > max_on_reg) begin
                        max_on_reg <= current_on_count;
                    end
                    
                    // Increment time counter
                    if (time_counter == 8'd255) begin
                        state <= FINISH;
                    end else begin
                        time_counter <= time_counter + 8'd1;
                    end
                end
                
                FINISH: begin
                    max_on <= max_on_reg;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule