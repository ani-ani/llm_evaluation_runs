module airline_scheduler (
    input clk,
    input rst_n,
    input start,
    input [1:0] n,
    input [1:0] m,
    input [15:0] inspection_times [0:3],
    input [15:0] flight_times [0:3][0:3],
    input [15:0] flight_reqs [0:3][0:3],
    output reg [7:0] result,
    output reg done
);

    // State definitions
    typedef enum logic [2:0] {
        IDLE,
        LOAD_DATA,
        CHECK_ADJ,
        FIND_COMPONENTS,
        DONE
    } state_t;

    state_t state;
    reg [1:0] flight_i, flight_j;
    reg [1:0] comp_i, comp_j;
    reg [3:0] visited [0:3];
    reg [3:0] adj [0:3][0:3];
    reg [15:0] flight_i_depart, flight_j_depart;
    reg [1:0] flight_i_src, flight_i_dest, flight_j_src, flight_j_dest;
    reg [15:0] arrival_time;
    reg [7:0] component_count;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            flight_i <= 0;
            flight_j <= 0;
            comp_i <= 0;
            comp_j <= 0;
            for (int k = 0; k < 4; k++) begin
                visited[k] <= 0;
                for (int l = 0; l < 4; l++) begin
                    adj[k][l] <= 0;
                end
            end
            result <= 0;
            done <= 0;
            component_count <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= LOAD_DATA;
                    end
                end
                LOAD_DATA: begin
                    state <= CHECK_ADJ;
                end
                CHECK_ADJ: begin
                    if (flight_i == m && flight_j == 0) begin
                        state <= FIND_COMPONENTS;
                    end else if (flight_j == m) begin
                        flight_i <= flight_i + 1;
                        flight_j <= 0;
                    end else begin
                        flight_i_src <= flight_reqs[flight_i][0];
                        flight_i_dest <= flight_reqs[flight_i][1];
                        flight_i_depart <= flight_reqs[flight_i][2];
                        flight_j_src <= flight_reqs[flight_j][0];
                        flight_j_dest <= flight_reqs[flight_j][1];
                        flight_j_depart <= flight_reqs[flight_j][2];
                        arrival_time <= flight_i_depart + flight_times[flight_i_dest][flight_j_src] + inspection_times[flight_j_src];
                        if (arrival_time <= flight_j_depart) begin
                            adj[flight_i][flight_j] <= 1;
                        end else begin
                            adj[flight_i][flight_j] <= 0;
                        end
                        flight_j <= flight_j + 1;
                    end
                end
                FIND_COMPONENTS: begin
                    if (comp_i == m) begin
                        state <= DONE;
                        result <= component_count;
                        done <= 1;
                    end else if (!visited[comp_i]) begin
                        component_count <= component_count + 1;
                        visited[comp_i] <= 1;
                        comp_j <= 0;
                    end else if (comp_j == m) begin
                        comp_i <= comp_i + 1;
                        comp_j <= 0;
                    end else if (adj[comp_i][comp_j] && !visited[comp_j]) begin
                        visited[comp_j] <= 1;
                        comp_j <= comp_j + 1;
                    end else begin
                        comp_j <= comp_j + 1;
                    end
                end
                DONE: begin
                    if (!start) begin
                        state <= IDLE;
                        done <= 0;
                    end
                end
            endcase
        end
    end

endmodule