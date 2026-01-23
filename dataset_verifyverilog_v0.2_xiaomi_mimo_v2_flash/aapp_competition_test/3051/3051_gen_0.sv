module fog_catcher(
    input clk,
    input rst_n,
    input start,
    input [4:0] fog_count,
    input [15:0] fog_day [0:15],
    input [7:0] fog_l [0:15],
    input [7:0] fog_r [0:15],
    input [7:0] fog_h [0:15],
    output reg [7:0] missed_count,
    output reg done
);

    // State encoding
    localparam IDLE = 3'b000;
    localparam LOAD_FOG = 3'b001;
    localparam CHECK_CONTAINMENT = 3'b010;
    localparam ADD_NET = 3'b011;
    localparam NEXT_FOG = 3'b100;
    localparam DONE = 3'b101;

    reg [2:0] state, next_state;
    
    // Fog registers for current processing
    reg [7:0] cur_l;
    reg [7:0] cur_r;
    reg [7:0] cur_h;
    
    // Nets storage
    reg [7:0] net_l [0:15];
    reg [7:0] net_r [0:15];
    reg [7:0] net_h [0:15];
    reg [3:0] net_count;
    
    // Index counters
    reg [3:0] fog_idx; // 0 to 15 max
    reg [3:0] net_idx; // 0 to 15 max
    
    // Helper flags
    reg found_containment;

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) next_state = LOAD_FOG;
                else next_state = IDLE;
            end
            LOAD_FOG: begin
                next_state = CHECK_CONTAINMENT;
            end
            CHECK_CONTAINMENT: begin
                // If we finished checking all nets
                if (net_idx >= net_count) begin
                    if (found_containment) next_state = NEXT_FOG;
                    else next_state = ADD_NET;
                end else begin
                    next_state = CHECK_CONTAINMENT; // Stay and check next net
                end
            end
            ADD_NET: begin
                next_state = NEXT_FOG;
            end
            NEXT_FOG: begin
                if (fog_idx + 1'b1 >= fog_count) begin
                    next_state = DONE;
                end else begin
                    next_state = LOAD_FOG;
                end
            end
            DONE: begin
                next_state = DONE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Datapath logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            missed_count <= 8'b0;
            done <= 1'b0;
            fog_idx <= 4'b0;
            net_idx <= 4'b0;
            net_count <= 4'b0;
            found_containment <= 1'b0;
            // Initialize nets (optional, for clean simulation)
            // Note: Verilog arrays of regs need explicit initialization in synthesis if desired,
            // but usually BRAM/Registers default to unknown or 0 depending on tool.
            // We rely on logic to handle valid data.
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        missed_count <= 8'b0;
                        done <= 1'b0;
                        fog_idx <= 4'b0;
                        net_count <= 4'b0;
                    end
                end
                
                LOAD_FOG: begin
                    // Load current fog data based on fog_idx
                    cur_l <= fog_l[fog_idx];
                    cur_r <= fog_r[fog_idx];
                    cur_h <= fog_h[fog_idx];
                    // Reset check variables
                    net_idx <= 4'b0;
                    found_containment <= 1'b0;
                end
                
                CHECK_CONTAINMENT: begin
                    // We check the net at current net_idx
                    // If we haven't found containment yet, check this net
                    if (!found_containment && (net_idx < net_count)) begin
                        // Check containment: [L, R] inside [net_l, net_r] AND H <= net_h
                        // Logic: net_l <= cur_l && cur_r <= net_r && cur_h <= net_h
                        if ((net_l[net_idx] <= cur_l) && 
                            (cur_r <= net_r[net_idx]) && 
                            (cur_h <= net_h[net_idx])) begin
                            found_containment <= 1'b1;
                        end
                    end
                    
                    // Increment index to move to next net in next cycle (unless we are done)
                    // We handle the increment carefully. 
                    // If we found containment immediately, we could skip rest, but FSM flow is linear.
                    // To optimize latency, we might want to skip, but keeping it simple:
                    // We will increment net_idx. 
                    // However, standard sequential logic: update net_idx to check next.
                    // If net_idx is max or we found containment, we should stop incrementing or wait for state transition.
                    // Let's stick to the loop: check one net per cycle.
                    // If found_containment becomes high, subsequent checks are wasted but harmless.
                    if (net_idx < net_count) begin
                        net_idx <= net_idx + 1'b1;
                    end
                end
                
                ADD_NET: begin
                    // If no containment found, add the net
                    if (net_count < 16) begin
                        net_l[net_count] <= cur_l;
                        net_r[net_count] <= cur_r;
                        net_h[net_count] <= cur_h;
                        net_count <= net_count + 1'b1;
                        missed_count <= missed_count + 1'b1;
                    end
                    // Note: If net_count >= 16, we cannot add. Logic might need to handle overflow,
                    // but requirements say max 16 nets, so we assume input fits.
                end
                
                NEXT_FOG: begin
                    fog_idx <= fog_idx + 1'b1;
                end
                
                DONE: begin
                    done <= 1'b1;
                end
            endcase
        end
    end

endmodule
