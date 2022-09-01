import Axios from "axios";

const api = Axios.create({
    baseURL: 'https://chatserver.app.haas-495.pez.vmware.com/api/',
});

const chatAPI = {
    getMessages: (groupId) => {
        console.log('Calling get messages from API');
        return api.get(`messages/${groupId}`);
    },

    sendMessage: (username, text) => {
        let msg = {
            sender: username,
            content: text
        }
        return api.post(`send`, msg);
    }
}


export default chatAPI;
